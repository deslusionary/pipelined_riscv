///////////////////////////////////////////////
// Filename:  stage_ex.sv
// Author: Christopher Tinker
// Date: 2022-02-02
//
// Description:
// 	Execute stage for 5 stage RISCV pipeline
///////////////////////////////////////////////

//`default_nettype none
`include "util.sv"

module stage_ex (
    input clk,
    input rst_i,
    input squash_i,
    input stall_i,

    // ID Stage inputs
    input id_ex_reg_t id_ex_i,

    // EX-MA Stage Pipeline Register
    output ex_ma_reg_t ex_ma_reg_o
    );

    ex_ma_reg_t ex_ma_r, ex_ma_n;
    logic [31:0] alu_result;

    /* ALU */
    alu ALU (
        .op1_i        (id_ex_i.alu_op1),
        .op2_i        (id_ex_i.alu_op2),
        .alu_fun_i    (id_ex_i.alu_fun),
        .result_o (alu_result)
    );

    /* Load-Store Unit */
    // This will be AXI (or something else) on the next revision
    // For now, all load-store signals are generated in decode

    /* EX-MA Pipeline Register */
    always_comb begin
        // Generate instr_valid signal
        if (id_ex_i.instr_valid && !squash_i) begin
            ex_ma_n.instr_valid = 1'b1;
        end

        else ex_ma_n.instr_valid = 1'b0;

        // Pass through signals headed to downstream stages
        ex_ma_n.pc_plus_four = id_ex_i.pc_plus_four;
        ex_ma_n.alu_result   = alu_result;
        
        // Memory Access Signals
        ex_ma_n.dmem_data  = id_ex_i.dmem_data;
        ex_ma_n.dmem_wr_en = id_ex_i.dmem_wr_en;
        ex_ma_n.dmem_rd_en = id_ex_i.dmem_rd_en;
        ex_ma_n.dmem_size  = id_ex_i.func3[1:0];
        ex_ma_n.dmem_sign  = id_ex_i.func3[2];

        // Writeback Signals
        ex_ma_n.reg_wr_en   = id_ex_i.reg_wr_en;
        ex_ma_n.reg_wr_sel  = id_ex_i.reg_wr_sel;
        ex_ma_n.reg_wr_addr = id_ex_i.reg_wr_addr;
    end

    always_ff @(posedge clk) begin
        // Synchronous reset invalidates current instruction
        if (rst_i) ex_ma_r.instr_valid <= 1'b0;

        else if (!stall_i) begin
            ex_ma_r <= ex_ma_n;
        end
    end

    assign ex_ma_reg_o = ex_ma_r;
endmodule