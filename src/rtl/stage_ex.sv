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
    input id_ex_reg_t id_ex_i,

    // EX-MA Stage Pipeline Register
    output ex_ma_reg_t  ex_ma_reg_o,
    output logic        instr_jalr_o,
    output logic        branch_taken_o,
    output logic [31:0] jalr_addr_o,
    output logic [31:0] branch_addr_o
    );

    ex_ma_reg_t ex_ma_r, ex_ma_n;
    logic [31:0] alu_result;
    logic [31:0] rs1_i_imm_sum; // Intermediate step for JALR address

    /* ALU */
    alu_onehot ALU (
        .op1_i        (id_ex_i.alu_op1),
        .op2_i        (id_ex_i.alu_op2),
        .alu_fun_i    (id_ex_i.alu_fun),
        .result_o (alu_result)
    );


    /* Branch Condition Generation */
    branch_cond_gen bcg (
        .data_rs1_i     (id_ex_i.alu_op1),
        .data_rs2_i     (id_ex_i.alu_op2),
        .func3_i        (id_ex_i.func3),
        .instr_branch_i (id_ex_i.instr_branch),
        .branch_taken_o (branch_taken_o)
    );


    // Branch Address Generation
    assign branch_addr_o = id_ex_i.branch_addr;
    // JALR Control
    assign rs1_i_imm_sum = id_ex_i.alu_op1 + id_ex_i.alu_op2;
    assign jalr_addr_o   = {rs1_i_imm_sum[31:1], 1'b0};
    assign instr_jalr_o  = id_ex_i.instr_jalr;


    /* EX-MA Pipeline Register */
    always_comb begin
        // Instruction in EX is valid if it was valid in previous stage 
        // and not squashed by hazard unit while in EX stage
        if (squash_i) begin
            ex_ma_n.valid = 1'b0;
            ex_ma_n.dmem_wr_en  = 1'b0;
        end

        else begin
            ex_ma_n.valid = id_ex_i.valid;
            ex_ma_n.dmem_wr_en  = id_ex_i.dmem_wr_en;
        end

        // Pass through signals headed to downstream stages
        ex_ma_n.pc_plus_four = id_ex_i.pc_plus_four;
        ex_ma_n.alu_result   = alu_result;
        
        // Memory Access Signals
        ex_ma_n.dmem_data  = id_ex_i.dmem_data;
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
        if (rst_i) ex_ma_r.valid <= 1'b0;

        else if (!stall_i) begin
            ex_ma_r <= ex_ma_n;
        end
    end

    assign ex_ma_reg_o = ex_ma_r;

// Suppress unused signal warnings
`ifdef VERILATOR
    wire _unused = &{1'b0, rs1_i_imm_sum[0], id_ex_i.rs1_used, id_ex_i.rs2_used,
        id_ex_i.rs1_addr, id_ex_i.rs2_addr};
`endif

endmodule
