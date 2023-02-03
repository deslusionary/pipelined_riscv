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

`default_nettype none
`include "util.sv"

module stage_decode(
        input             clk,
        input             rst_i,
        input             stall_i,
        input             squash_i, 

        // Inputs from IF Stage
        input [31:0]      instr_i,
        input if_id_reg_t if_id_reg_i,

        // As register file is instantiated in top-level module, register file
        // read data outputs are passed into the decode stage
        input [31:0]      data_rs1_i,
        input [31:0]      data_rs2_i,
        
        // ID-EX Stage Pipeline Register Outputs
        output id_ex_reg_t  id_ex_reg_o,

        // NON-REGISTERED OUTPUTS
        // Control flow signals for IF stage PC control
        output logic        instr_jal_o, // Tell IF to load PC with JAL target address
        output logic        instr_jalr_o, // Load PC with JALR target address
        output logic        branch_taken_o, // Asserted if branch is taken
        output logic [31:0] jal_addr_o,
        output logic [31:0] branch_addr_o,
        output logic [31:0] jalr_addr_o
    );

    // Signals passed to downstream stages
    id_ex_reg_t id_ex_reg;
    id_ex_reg_t id_ex_next;

    // ID-only signals
    logic       alu_op1_sel;
    logic [1:0] alu_op2_sel; 
    
    logic [31:0] u_type_imm;
    logic [31:0] i_type_imm;
    logic [31:0] s_type_imm;
    logic [31:0] j_type_imm;
    logic [31:0] b_type_imm;
    logic        instr_branch;
    
    /* Instruction Decode */
    instr_decoder riscv_decoder (
        .opcode_i       (instr_i[6:0]),
        .func3_i        (instr_i[14:12]),
        .func7_i        (instr_i[30]), 
        
        // ALU Control
        .alu_fun_o      (id_ex_next.alu_fun), // Pass to EX stage
        .alu_op1_sel_o  (alu_op1_sel),
        .alu_op2_sel_o  (alu_op2_sel),

        // Register File Writeback Control
        .reg_wr_en_o    (id_ex_next.reg_wr_en),
        .reg_wr_sel_o   (id_ex_next.reg_wr_sel),

        // LSU
        .dmem_rd_en_o   (id_ex_next.dmem_rd_en),
        .dmem_wr_en_o   (id_ex_next.dmem_wr_en),

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
    assign branch_addr_o = if_id_reg_i.pc + b_type_imm;
    assign jal_addr_o    = if_id_reg_i.pc + j_type_imm;
    assign jalr_addr_o   = data_rs1_i + i_type_imm;

    /* Branch condition generation */
    always_comb begin
        branch_taken_o = 1'b0;

        case (instr_i[14:12])
        endcase

        // if instr_branch and branch condition is true then assert branch_taken_o
    end
    

    /* Select ALU Operand 1 */
    always_comb begin : alu_op1_sel
        unique case (alu_op1_sel)
            1'b0: id_ex_next.alu_op1 = data_rs1_i;
            1'b1: id_ex_next.alu_op1 = u_type_imm;
        endcase
    end


    /* Select ALU Operand 2 */
    always_comb begin
        unique case (alu_op2_sel)
            2'b00: id_ex_next.alu_op2 = data_rs2_i;
            2'b01: id_ex_next.alu_op2 = i_type_imm;
            2'b10: id_ex_next.alu_op2 = s_type_imm;
            2'b11: id_ex_next.alu_op2 = if_id_reg_i.pc;
        endcase
    end


    /* Instruction Squash Control */
    // Add illegal instruction detection to this in future
    always_comb begin
        if (if_id_reg_i.instr_valid && !squash_i) begin
            id_ex_next.instr_valid = 1'b1;
        end

        else id_ex_next.instr_valid = 1'b0;
    end
    

    /* ID-EX Pipeline Register */ 
    always_comb begin
        id_ex_next.pc = if_id_reg_i.pc;
        id_ex_next.pc_plus_four = if_id_reg_i.pc_plus_four;
        id_ex_next.func3 = instr_i[14:12]; // func3
        id_ex_next.dmem_data = data_rs2_i;
        id_ex_next.reg_wr_addr = instr_i[11:7];
    end

    always_ff @(posedge clk) begin : id_ex_reg
        if (rst_i) id_ex_reg.instr_valid <= '0; // invalidate instruction on reset

        else if (!stall_i) begin
            id_ex_reg <= id_ex_next;
        end
    end
    
endmodule
