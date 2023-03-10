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
        output logic [31:0] jal_addr_o
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
    logic        rs1_used;
    logic        rs2_used;
    
    logic [31:0] u_type_imm;
    logic [31:0] i_type_imm;
    logic [31:0] s_type_imm;
    logic [31:0] j_type_imm;
    logic [31:0] b_type_imm;
    logic        instr_branch;
    logic        instr_jalr;
    logic        instr_jal;
    logic [31:0] branch_addr;
    
    /* Instruction Decode */
    instr_decoder riscv_decoder (
        .opcode_i       (instr_i[6:0]),
        .func3_i        (instr_i[14:12]),
        .func7_i        (instr_i[30]), 
        
        .alu_fun_o      (alu_fun), // Pass to EX stage
        .alu_op1_sel_o  (alu_op1_sel),
        .alu_op2_sel_o  (alu_op2_sel),
        .reg_wr_en_o    (reg_wr_en),
        .reg_wr_sel_o   (reg_wr_sel),
        .dmem_rd_en_o   (dmem_rd_en),
        .dmem_wr_en_o   (dmem_wr_en),
        .instr_jalr_o   (instr_jalr),
        .instr_jal_o    (instr_jal),
        .instr_branch_o (instr_branch),
        .rs1_used_o     (rs1_used),
        .rs2_used_o     (rs2_used)
    );
    
    /* Immediate Value Generation */
    assign u_type_imm = {instr_i[31:12], 12'b0};
    assign i_type_imm = {{21{instr_i[31]}}, instr_i[30:25], instr_i[24:20]};
    assign s_type_imm = {{21{instr_i[31]}}, instr_i[30:25], instr_i[11:7]};
    assign j_type_imm = {{12{instr_i[31]}}, instr_i[19:12], instr_i[20], instr_i[30:21], 1'b0};
    assign b_type_imm = {{20{instr_i[31]}}, instr_i[7], instr_i[30:25], instr_i[11:8], 1'b0};
    

    /* Branch/JAL/JALR Target Address Generation */
    assign branch_addr   = if_id_i.pc + b_type_imm;
    assign jal_addr_o    = if_id_i.pc + j_type_imm;

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

        id_ex_n.pc_plus_four = if_id_i.pc_plus_four;
        id_ex_n.func3        = instr_i[14:12]; // func3
        id_ex_n.ex_ma_intlk  = (instr_jal_o || dmem_rd_en);

        id_ex_n.alu_fun      = alu_fun;
        id_ex_n.dmem_data    = data_rs2_i;
        id_ex_n.dmem_rd_en   = dmem_rd_en;
        id_ex_n.instr_branch = instr_branch;
        id_ex_n.instr_jalr   = instr_jalr;
        id_ex_n.branch_addr  = branch_addr;
        id_ex_n.rs1_used     = rs1_used;
        id_ex_n.rs2_used     = rs2_used;
        id_ex_n.rs1_addr     = instr_i[19:15];
        id_ex_n.rs2_addr     = instr_i[24:20];
        id_ex_n.reg_wr_en    = (instr_i[11:7] == '0) ? '0 :reg_wr_en;
        id_ex_n.reg_wr_sel   = reg_wr_sel;
        id_ex_n.reg_wr_addr  = instr_i[11:7];    
    end

    always_ff @(posedge clk) begin
        if (rst_i) id_ex_r.valid <= '0; // invalidate instruction on reset

        else if (!stall_i) begin
            id_ex_r <= id_ex_n;
        end
    end 

    assign instr_jal_o = (instr_jal && if_id_i.valid && !squash_i);
    assign id_ex_reg_o = id_ex_r;

// Suppress Verilator warnings about intentionally unused signals
`ifdef VERILATOR
`endif
    
endmodule
