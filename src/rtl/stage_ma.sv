///////////////////////////////////////////////
// Filename:  stage_ma.sv
// Author: Christopher Tinker
// Date: 2022-01-31
//
// Description:
//  Memory Access stage for RV32I 5-stage pipeline
///////////////////////////////////////////////

`include "util.sv"

module stage_ma (
    input logic        clk,
    input logic        rst_i,
    input logic        stall_i,
    input logic        squash_i,
    input ex_ma_reg_t  ex_ma_i, // EX-MA pipeline register in

    output ma_wb_reg_t ma_wb_reg_o
);
    ma_wb_reg_t ma_wb_r; // MA-WB stage pipeline register
    ma_wb_reg_t ma_wb_n; // Next MA-WB register value

    /* MA-WB Pipeline Register */
    always_comb begin
        // Instruction valid only if previously valid and not squashed by 
        // hazard unit in current stage
        if (squash_i) ma_wb_n.instr_valid = 1'b0;
        else          ma_wb_n.instr_valid = ex_ma_i.instr_valid;

        ma_wb_n.pc_plus_four = ex_ma_i.pc_plus_four;
        ma_wb_n.alu_result   = ex_ma_i.alu_result;
        ma_wb_n.reg_wr_en    = ex_ma_i.reg_wr_en;
        ma_wb_n.reg_wr_sel   = ex_ma_i.reg_wr_sel;
        ma_wb_n.reg_wr_addr  = ex_ma_i.reg_wr_addr;
    end

    always_ff @(posedge clk) begin
        if (rst_i) ma_wb_r.instr_valid <= 1'b0;

        else if (!stall_i) begin
            ma_wb_r <= ma_wb_n;
        end
    end

    assign ma_wb_reg_o = ma_wb_r;

// Stop Verilator from complaining about the damn unused signals
`ifdef VERILATOR
    wire _unused = &{
        1'b0, 
        ex_ma_i.dmem_data, 
        ex_ma_i.dmem_rd_en,
        ex_ma_i.dmem_wr_en,
        ex_ma_i.dmem_size,
        ex_ma_i.dmem_sign};
`endif
    
endmodule
