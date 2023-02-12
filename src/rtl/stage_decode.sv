`timescale 1ns / 1ps
///////////////////////////////////////////////
// Filename:  stage_decodesv
// Author: Christopher Tinker
// Date: 2022-02-01
//
// Description:
// 	Instruction decode stage for 5-stage in-order
// RV32I pipeline
///////////////////////////////////////////////

//`default_nettype none
`include "util.sv"
`include "instr_formats.svh"

module stage_decode (
        input             clk,
        input             rst_i,
        input             stall_i,
        input             squash_i, 

        // Inputs from IF Stage
        input [31:0]      instr_i,
        input if_id_reg_t if_id_i,

        // As register file is instantiated in top-level module, register file
        // read data outputs are passed into the decode stage
        input [31:0]      data_rs1_i,
        input [31:0]      data_rs2_i,
        
        // ID-EX Stage Pipeline Register
        output id_ex_reg_t  id_ex_reg_o,

        // NON-REGISTERED OUTPUTS
        // Control flow signals for IF stage PC control
        output logic        instr_jal_o, // Tell IF to load PC with JAL target address
        output logic        instr_jalr_o, // Load PC with JALR target address
        output logic        branch_taken_o, // Asserted if branch is taken
        output logic [31:0] jal_addr_o,
        output logic [31:0] jalr_addr_o,
        output logic [31:0] branch_addr_o
    );

    // Signals passed to downstream stages
    id_ex_reg_t id_ex_r; // ID-EX stage pipeline register
    id_ex_reg_t id_ex_n; // next ID-EX register value

    logic [10:0] alu_fun;
    logic        alu_op1_sel;
    logic [1:0]  alu_op2_sel; 
    logic        dmem_rd_en;
    logic        dmem_wr_en;
    logic        reg_wr_en;
    logic [1:0]  reg_wr_sel;
    
    logic [31:0] u_type_imm;
    logic [31:0] i_type_imm;
    logic [31:0] s_type_imm;
    logic [31:0] j_type_imm;
    logic [31:0] b_type_imm;
    logic [31:0] rs1_i_imm_sum;
    logic        instr_branch;

    logic        br_eq;
    logic        br_lt;
    logic        br_ltu;
    logic        branch_cond_true;
    
    /* Instruction Decode */
    instr_decoder riscv_decoder (
        .opcode_i       (instr_i[6:0]),
        .func3_i        (instr_i[14:12]),
        .func7_i        (instr_i[30]), 
        
        // ALU Control
        .alu_fun_o      (alu_fun), // Pass to EX stage
        .alu_op1_sel_o  (alu_op1_sel),
        .alu_op2_sel_o  (alu_op2_sel),

        // Register File Writeback Control
        .reg_wr_en_o    (reg_wr_en),
        .reg_wr_sel_o   (reg_wr_sel),

        // LSU
        .dmem_rd_en_o   (dmem_rd_en),
        .dmem_wr_en_o   (dmem_wr_en),

        // PC Control
        .instr_jalr_o   (instr_jalr_o),
        .instr_jal_o    (instr_jal_o),
        .instr_branch_o (instr_branch)
    );
    
    /* Immediate Value Generation */
    assign u_type_imm = {instr_i[31:12], 12'b0};
    assign i_type_imm = {{21{instr_i[31]}}, instr_i[30:25], instr_i[24:20]};
    assign s_type_imm = {{21{instr_i[31]}}, instr_i[30:25], instr_i[11:7]};
    assign j_type_imm = {{12{instr_i[31]}}, instr_i[19:12], instr_i[20], instr_i[30:21], 1'b0};
    assign b_type_imm = {{20{instr_i[31]}}, instr_i[7], instr_i[30:25], instr_i[11:8], 1'b0};
    

    /* Branch/JAL/JALR Target Address Generation */
    assign branch_addr_o = if_id_i.pc + b_type_imm;
    assign jal_addr_o    = if_id_i.pc + j_type_imm;
    assign rs1_i_imm_sum = data_rs1_i + i_type_imm;
    assign jalr_addr_o   = {rs1_i_imm_sum[31:1], 1'b0};

    /* Branch Condition Generation */
    assign br_eq  = (data_rs1_i == data_rs2_i);
    assign br_lt  = ($signed(data_rs1_i) < $signed(data_rs2_i));
    assign br_ltu = (data_rs1_i < data_rs2_i);

    always_comb begin
        
        // Determine if branch condition is true
        case (instr_i[14:12])  // func3 field - instr[14:12]
            `BEQ:  branch_cond_true = br_eq;
            `BNE:  branch_cond_true = ~br_eq;
            `BLT:  branch_cond_true = br_lt;
            `BGE:  branch_cond_true = ~br_lt;
            `BLTU: branch_cond_true = br_ltu;
            `BGEU: branch_cond_true = ~br_ltu;

            default: branch_cond_true = 1'b0; // TODO: throw exception
        endcase
        // Take the branch if instruction is a branch, and the branch condition is true
        branch_taken_o = (instr_branch && branch_cond_true) ? 1'b1 : 1'b0;
    end
    

    /* Select ALU Operand 1 */
    always_comb begin
        unique case (alu_op1_sel)
            1'b0: id_ex_n.alu_op1 = data_rs1_i; // Register rs1
            1'b1: id_ex_n.alu_op1 = u_type_imm; // U-type immediate
        endcase
    end


    /* Select ALU Operand 2 */
    always_comb begin
        unique case (alu_op2_sel)
            2'b00: id_ex_n.alu_op2 = data_rs2_i; // Register rs2
            2'b01: id_ex_n.alu_op2 = i_type_imm; // I type immediate
            2'b10: id_ex_n.alu_op2 = s_type_imm; // S type immediate
            2'b11: id_ex_n.alu_op2 = if_id_i.pc; // Instruction program counter
        endcase
    end


    /* ID-EX Pipeline Register */ 
    always_comb begin
        /* Instruction Squash Control */
        // Add illegal instruction detection to this in future
        if (squash_i) begin
            id_ex_n.valid = 1'b0;
            id_ex_n.dmem_wr_en  = 1'b0;
        end

        else begin
            id_ex_n.valid = if_id_i.valid;
            id_ex_n.dmem_wr_en  = dmem_wr_en;
        end

        //id_ex_n.pc = if_id_i.pc; // Do later stages need PC? Don't think so
        id_ex_n.pc_plus_four = if_id_i.pc_plus_four;
        id_ex_n.func3       = instr_i[14:12]; // func3

        id_ex_n.alu_fun     = alu_fun;
        id_ex_n.dmem_data   = data_rs2_i;
        id_ex_n.dmem_rd_en  = dmem_rd_en;
        
        id_ex_n.reg_wr_en   = reg_wr_en;
        id_ex_n.reg_wr_sel  = reg_wr_sel;
        id_ex_n.reg_wr_addr = instr_i[11:7];    
    end

    always_ff @(posedge clk) begin
        if (rst_i) id_ex_r.valid <= '0; // invalidate instruction on reset

        else if (!stall_i) begin
            id_ex_r <= id_ex_n;
        end
    end

    assign id_ex_reg_o = id_ex_r;

// Suppress Verilator warnings about intentionally unused signals
`ifdef VERILATOR
    wire _unused = &{1'b0, rs1_i_imm_sum[0]};
`endif
    
endmodule
