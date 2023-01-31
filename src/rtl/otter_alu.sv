`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Engineer:       Christopher Tinker
// Create Date:    2022/01/21
// Design Name:    OTTER ALU
// Module Name:    ALU
// Project Name:   CPE233 OTTER MCU
// Target Devices: Xilinx Artix 7 
// Description:    OTTER RV32I Arithmetic Logic Unit (ALU). Implements all arithmetic
//                 and logic operations specified by the RISCV RV32I 32-bit integer
//                 base instruction set architecture.
// 
// Revision:
// Revision 0.01 - File Created
//////////////////////////////////////////////////////////////////////////////////


module alu (
        input [31:0] op_1,
        input [31:0] op_2,
        input [3:0] alu_fun,
        output logic [31:0] result
    );
    
    // parameter table for ALU functions
//    localparam alu_add  = 4'b0000; // addition
//    localparam alu_sub  = 4'b1000; // subtraction
//    localparam alu_or   = 4'b0110; // bitwise or
//    localparam alu_and  = 4'b0111; // bitwise and
//    localparam alu_xor  = 4'b0100; // bitwise xor
//    localparam alu_srl  = 4'b0101; // logical shift right
//    localparam alu_sl1  = 4'b0001; // logical shift left
//    localparam alu_sra  = 4'b1101; // arithmetic shift right
//    localparam alu_slt  = 4'b0010; // set if less than
//    localparam alu_sltu = 4'b0011; // set if less than unsigned
//    localparam alu_lui  = 4'b1001; // load upper immediate
    
    typedef enum logic [3:0] {
        alu_add  = 4'b0000, // addition
        alu_sub  = 4'b1000, // subtraction
        alu_or   = 4'b0110, // bitwise or
        alu_and  = 4'b0111, // bitwise and
        alu_xor  = 4'b0100, // bitwise xor
        alu_srl  = 4'b0101, // logical shift right
        alu_sll  = 4'b0001, // logical shift left
        alu_sra  = 4'b1101, // arithmetic shift right
        alu_slt  = 4'b0010, // set if less than
        alu_sltu = 4'b0011, // set if less than unsigned
        alu_lui  = 4'b1001  // load upper immediate
    } alu_fun_dt;
    
    alu_fun_dt ALU_FUN;
    assign ALU_FUN = alu_fun_dt'(alu_fun); // cast alu_fun input to alu_fun_dt enum type
    
    // model ALU operation
    always @(*) begin
        case (ALU_FUN)
            alu_add  : result = op_1 + op_2; // add
            alu_sub  : result = op_1 - op_2; // sub
            alu_or   : result = op_1 | op_2; // or
            alu_and  : result = op_1 & op_2; // and
            alu_xor  : result = op_1 ^ op_2; // xor
            alu_srl  : result = op_1 >> op_2[4:0]; // srl
            alu_sll  : result = op_1 << op_2[4:0]; // sll
            alu_sra  : result = $signed(op_1) >>> op_2[4:0]; // sra
            alu_slt  : result = {31'b0, $signed(op_1) < $signed(op_2)}; // slt is signed
            alu_sltu : result = {31'b0, op_1 < op_2}; // sltu is unsigned
            alu_lui  : result = op_1; // lui
            
            // prevent latch generation with default case
            default  : result = 32'hdead_beef;
        endcase
    end
    
endmodule