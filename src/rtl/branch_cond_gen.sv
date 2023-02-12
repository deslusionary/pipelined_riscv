///////////////////////////////////////////////
// Filename:  branch_cond_gen.sv
// Author: Christopher Tinker
// Date: 2022-02-11
//
// Description:
// 	All-combinatorial RV32 branch condition
//  generation
///////////////////////////////////////////////

`include "instr_formats.svh"

module branch_cond_gen (
    input logic [31:0] data_rs1_i,
    input logic [31:0] data_rs2_i,
    input logic [2:0]  func3_i,
    input logic        instr_branch_i,

    output logic       branch_taken_o
    );

    logic br_eq;
    logic br_lt;
    logic br_ltu;
    logic branch_cond_true;

    assign br_eq  = (data_rs1_i == data_rs2_i);
    assign br_lt  = ($signed(data_rs1_i) < $signed(data_rs2_i));
    assign br_ltu = (data_rs1_i < data_rs2_i);

    always_comb begin
        
        // Determine if branch condition is true
        case (func3_i)  // func3 field - instr[14:12]
            `BEQ:  branch_cond_true = br_eq;
            `BNE:  branch_cond_true = ~br_eq;
            `BLT:  branch_cond_true = br_lt;
            `BGE:  branch_cond_true = ~br_lt;
            `BLTU: branch_cond_true = br_ltu;
            `BGEU: branch_cond_true = ~br_ltu;

            default: branch_cond_true = 1'b0; // TODO: loudly complain -- invalid func3 field
        endcase

        // Take the branch if instruction is a branch, and the branch condition is true
        branch_taken_o = (instr_branch_i && branch_cond_true) ? 1'b1 : 1'b0;
    end
    
endmodule
