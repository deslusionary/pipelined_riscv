`timescale 1ns / 1ps
///////////////////////////////////////////////
// Filename:  stage_fetch.sv
// Author: Christopher Tinker
// Date: 2022-02-02
//
// Description:
// 	Fetch stage and processor frontend for 
// pipelined RV32I core
///////////////////////////////////////////////

`include "util.sv"

module stage_fetch(
    input clk,
    input rst_i,
    input stall_i,
    input squash_i,
        
    // ID stage PC control signals
    input instr_jal_i,
    input instr_jalr_i,
    input branch_taken_i,
    input [31:0] jal_addr_i,
    input [31:0] branch_addr_i,
    input [31:0] jalr_addr_i,
        
    // Instruction Fetch Interface
    // Instruction data (MEM_DOUT1 port on RAM) connected directly to ID stage
    output logic [31:0] imem_addr_o,
    output logic        imem_rd_en_o,    
        
    // IF-ID pipeline register
    output if_id_reg_t  if_id_reg_o  
    );
    
    if_id_reg_t if_id_r; // IF-ID pipeline register
    if_id_reg_t if_id_n; // IF-ID pipeline register next value
    
    logic [31:0] pc_r; // program counter
    logic [31:0] pc_n; // next program counter
    logic [31:0] pc_plus_four;

    
    /* Program Counter */
    assign pc_plus_four = pc_r + 4;
    
    // Select correct next PC value
    always_comb begin : next_pc_mux
        // Very important that only one of instr_jal_i, instr_jalr_i, or 
        // instr_branch_i are asserted at the same time! 
        // This is checked with SVA in instr_decoder
        if (instr_jalr_i)        pc_n = jalr_addr_i;
        else if (instr_jal_i)    pc_n = jal_addr_i;
        else if (branch_taken_i) pc_n = branch_addr_i;
        else                     pc_n = pc_plus_four;
    end
    
    always_ff @(posedge clk) begin : pc_reg
        if (rst_i) 
            pc_r <= '0; // Could hardcode a reset address vector location here
        else if (!stall_i) 
            pc_r <= pc_n; // TODO: anything else that would stop PC from loading next value? WFI?
    end
    

    /* Instruction fetch control */
    assign imem_addr_o = pc_r;
    assign imem_rd_en_o = !stall_i; // Can this signal stay asserted? Always be fetchin'?
    

    /* IF-ID Pipeline Register */
    always_comb begin
        // This will need updating to support I$ or memory errors!
        if_id_n.valid = (squash_i) ? 1'b0 : 1'b1;
        if_id_n.pc = pc_r;
        if_id_n.pc_plus_four = pc_plus_four;
    end
    
    always_ff @(posedge clk) begin
        if (rst_i) if_id_r.valid <= 1'b0; // handle resets by invalidating current instruction
        
        else if (!stall_i) begin
            if_id_r <= if_id_n;
        end
    end

    assign if_id_reg_o = if_id_r; 
    
endmodule
