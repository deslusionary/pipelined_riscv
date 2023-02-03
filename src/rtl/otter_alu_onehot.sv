///////////////////////////////////////////////
// Filename:  otter_alu_onehot.sv
// Author: Christopher Tinker
// Date: 2022-01-28
//
// Description:
// 	ALU for pipelined RV32I CPU. Implements one-hot ALU
// control signal design discussed in Miyazaki, "RVCoreP,
// An optimized RISC-V soft processor of five-stage pipelining".
///////////////////////////////////////////////


/* ALU module with one hot control signal frequency optimization
*/

`include "util.sv"

module otter_alu (
        input [31:0] op1_i,
        input [31:0] op2_i,
        input [10:0] alu_fun_i,
        output logic [31:0] result_o
    );
 
    // Variable instantiations
    wire logic [31:0] alu_results [10:0];

    // Big ol' ALU assign block
    assign alu_results[0]  = alu_fun_i[0]  ? op1_i + op2_i : 32'b0; // ADD/ADDI
    assign alu_results[1]  = alu_fun_i[1]  ? op1_i << op2_i[4:0]: 32'b0; // SLL/SLLI
    assign alu_results[2]  = alu_fun_i[2]  ? {31'b0, $signed(op1_i) < $signed(op2_i)} : 32'b0;
    assign alu_results[3]  = alu_fun_i[3]  ? {31'b0, op1_i < op2_i} : 32'b0;
    assign alu_results[4]  = alu_fun_i[4]  ? op1_i ^ op2_i : 32'b0;
    assign alu_results[5]  = alu_fun_i[5]  ? op1_i >> op2_i[4:0] : 32'b0;
    assign alu_results[6]  = alu_fun_i[6]  ? op1_i | op2_i : 32'b0;
    assign alu_results[7]  = alu_fun_i[7]  ? op1_i & op2_i : 32'b0;
    assign alu_results[8]  = alu_fun_i[8]  ? op1_i - op2_i : 32'b0; 
    assign alu_results[9]  = alu_fun_i[9]  ? $signed(op1_i) >>> op2_i[4:0] : 32'b0;
    assign alu_results[10] = alu_fun_i[10]  ? op1_i : 32'b0; // LUI

    // XOR results of all ALU operations together to get correct ALU result
    always_comb begin
        result_o = 32'b0; // latch/combinatorial loop prevention

        for (integer i = 0; i < $size(alu_results); i++) begin
            result_o ^= alu_results[i];
        end
    end

`ifdef SIM
    // Input assumptions for sim and formal
    always_comb begin
        alu_fun_onehot: assume ($onehot(alu_fun_i) || alu_fun_i == '0);
    end
`endif

`ifdef FORMAL
    // Formal variables
    integer count_nonzero;
    
    // input assumptions
    always_comb begin
        assume ($onehot(alu_fun_i));
    end

    // Formal tests
    always_comb begin
        // test that no more than one alu_result array element != 0
        count_nonzero = 0;

        for (integer i = 0; i < $size(alu_results); i++) begin
            if (alu_results[i] != 32'b0) count_nonzero += 1'b1;
        end

        max_one_nonzerresult_o: assert(!(count_nonzero > 1));

    end


`endif // FORMAL

endmodule