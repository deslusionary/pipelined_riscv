///////////////////////////////////////////////
// Filename:  instr_formats.svh
// Author: Christopher Tinker
// Date: 2022-01-31
//
// Description:
// 	SystemVerilog Header file containing
// macros for RV32 instruction opcode and function
// field formats.
///////////////////////////////////////////////

`ifndef INSTR_FORMATS
`define INSTR_FORMATS

//////////////////////////////////////////////
/* OPCODE (ir[6:0])                         */
/////////////////////////////////////////////
`define LUI    7'b0110111
`define AUIPC  7'b0010111
`define JAL    7'b1101111
`define JALR   7'b1100111
`define BRANCH 7'b1100011
`define LOAD   7'b0000011
`define STORE  7'b0100011
`define OP_IMM 7'b0010011
`define OP_REG 7'b0110011
`define SYSTEM 7'b1110011


/////////////////////////////////////////////
/* BRANCH FUNC3 Field (ir[14:12]           */
/////////////////////////////////////////////
`define BEQ  3'b000
`define BNE  3'b001
`define BLT  3'b100
`define BGE  3'b101
`define BLTU 3'b110
`define BGEU 3'b111


/////////////////////////////////////////////
/* FUNC3 field for I- and R- type ALU 
 * instructions (ir[14:12])                */
/////////////////////////////////////////////
`define OP_SUM  3'b000 // ADD, ADDI, SUB instructions
`define OP_SLL  3'b001 // SLL, SLLI
`define OP_SLT  3'b010 // SLT, SLTI
`define OP_SLTU 3'b011 // SLTU, SLTIU
`define OP_XOR  3'b100 // XOR, XORI
`define OP_SR   3'b101 // SRL, SRLI, SRA, SRAI
`define OP_OR   3'b110 // OR, ORI
`define OP_AND  3'b111 // AND, ANDI


`endif // INSTR_FORMATS

