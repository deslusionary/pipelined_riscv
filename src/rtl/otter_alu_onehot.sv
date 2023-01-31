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

typedef struct packed {
        logic lui; // load upper immediate alu_fun_t[10]
        logic sra; // alu_fun_t[9] shift right arithmetic 
        logic sub;
        logic fun_and;
        logic fun_or;
        logic srl; // shift right logical
        logic fun_xor;
        logic sltu; //set less than unsigned
        logic slt; // set less than
        logic sll;  // shift left logical
        logic add; // alu_fun_t[0]

    } alu_fun_t;

module otter_alu (
        input [31:0] i_op_1,
        input [31:0] i_op_2,
        input alu_fun_t i_alu_fun,
        output logic [31:0] o_result
    );

    // Variable instantiations
    wire logic [31:0] alu_results [10:0];

    // Big ol' ALU assign block
    assign alu_results[0]  = i_alu_fun.add     ? i_op_1 + i_op_2 : 32'b0; // ADD/ADDI
    assign alu_results[1]  = i_alu_fun.sll     ? i_op_1 << i_op_2[4:0]: 32'b0; // SLL/SLLI
    assign alu_results[2]  = i_alu_fun.slt     ? {31'b0, $signed(i_op_1) < $signed(i_op_2)} : 32'b0;
    assign alu_results[3]  = i_alu_fun.sltu    ? {31'b0, i_op_1 < i_op_2} : 32'b0;
    assign alu_results[4]  = i_alu_fun.fun_xor ? i_op_1 ^ i_op_2 : 32'b0;
    assign alu_results[5]  = i_alu_fun.srl     ? i_op_1 >> i_op_2[4:0] : 32'b0;
    assign alu_results[6]  = i_alu_fun.fun_or  ? i_op_1 | i_op_2 : 32'b0;
    assign alu_results[7]  = i_alu_fun.fun_and ? i_op_1 & i_op_2 : 32'b0;
    assign alu_results[8]  = i_alu_fun.sub     ? i_op_1 - i_op_2 : 32'b0; 
    assign alu_results[9]  = i_alu_fun.sra     ? $signed(i_op_1) >>> i_op_2[4:0] : 32'b0;
    assign alu_results[10] = i_alu_fun.lui     ? i_op_1 : 32'b0;

    // XOR results of all ALU operations together to get correct ALU result
    always_comb begin
        o_result = 32'b0; // latch/combinatorial loop prevention

        for (integer i = 0; i < $size(alu_results); i++) begin
            o_result ^= alu_results[i];
        end
    end

`ifdef SIM
    // Input assumptions for sim and formal
    always_comb begin
        alu_fun_onehot: assume ($onehot(i_alu_fun));
    end
`endif

`ifdef FORMAL
    // Formal variables
    integer count_nonzero;
    
    // input assumptions
    always_comb begin
        assume ($onehot(i_alu_fun));
    end

    // Formal tests
    always_comb begin
        // test that no more than one alu_result array element != 0
        count_nonzero = 0;

        for (integer i = 0; i < $size(alu_results); i++) begin
            if (alu_results[i] != 32'b0) count_nonzero += 1'b1;
        end

        max_one_nonzero_result: assert(!(count_nonzero > 1));

    end


`endif // FORMAL

endmodule