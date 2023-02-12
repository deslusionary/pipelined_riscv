///////////////////////////////////////////////
// Filename:  util_types.sv
// Author: Christopher Tinker
// Date: 2022-01-31
//
// Description:
// 	Reusable tility types, structs, and pipeline register
// for pipelined RV32I core
///////////////////////////////////////////////

//package util_types;
`ifndef UTIL_TYPES
`define UTIL_TYPES

////////////////////////////////////////
/* One-hot encoded ALU control signal */
////////////////////////////////////////
`define ALU_LUI  11'b10000000000
`define ALU_SRA  11'b01000000000
`define ALU_SUB  11'b00100000000
`define ALU_AND  11'b00010000000
`define ALU_OR   11'b00001000000
`define ALU_SRL  11'b00000100000
`define ALU_XOR  11'b00000010000
`define ALU_SLTU 11'b00000001000
`define ALU_SLT  11'b00000000100
`define ALU_SLL  11'b00000000010
`define ALU_ADD  11'b00000000001

//////////////////////////////////
/* Stage pipeline registers     */
//////////////////////////////////

// Fetch - DECODE Pipeline Register
typedef struct packed {
    logic        valid;
    logic [31:0] pc;
    logic [31:0] pc_plus_four;
} if_id_reg_t;

// DECODE - EXECUTE Pipeline Register
typedef struct packed {
    //// Instruction State ////
    logic          valid;
    logic [31:0]   pc_plus_four;
    logic [2:0]    func3;
    
    //// EXECUTE ////
    // ALU
    logic [31:0] alu_op1;
    logic [31:0] alu_op2;
    logic [10:0] alu_fun;
    // LSU 
    logic        dmem_rd_en;
    logic        dmem_wr_en;
    logic [31:0] dmem_data;
    // BCG
    logic        instr_branch;
    logic        instr_jalr;
    logic [31:0] branch_addr;
    
    //// WRITEBACK ////
    logic       reg_wr_en;
    logic [1:0] reg_wr_sel;
    logic [4:0] reg_wr_addr;
} id_ex_reg_t;                // TODO: forwarding support


typedef struct packed {
    logic valid;
    // logic [31:0] pc; // is PC really needed past this point?
    logic [31:0] pc_plus_four;
    
    // ALU
    logic [31:0] alu_result;
    // LSU
    logic        dmem_rd_en;
    logic        dmem_wr_en;
    logic [31:0] dmem_data;
    logic [1:0]  dmem_size;
    logic        dmem_sign;

    logic        reg_wr_en;
    logic [1:0]  reg_wr_sel;
    logic [4:0]  reg_wr_addr;
} ex_ma_reg_t;                // TODO: state signals needed for forwarding

typedef struct packed {
    logic        valid;
    logic [31:0] pc_plus_four;
    logic [31:0] alu_result;
    logic        reg_wr_en;
    logic [1:0]  reg_wr_sel;
    logic [4:0]  reg_wr_addr;
} ma_wb_reg_t;


//////////////////////////////
///* RISCV Instruction Decode Utility Types /*
//////////////////////////////

// typedef struct packed {
//     logic lui;
//     logic auipc;
//     logic jal;
//     logic jalr;
//     logic branch;
//     logic load;
//     logic store;
//     logic op_imm;
//     logic op_reg;
//     logic system;
// } opcode_t;

///* RISCV Instruction OPCODE field - IR[6:0] */
//typedef enum logic [6:0] {
//    LUI    = 7'b0110111,
//    AUIPC  = 7'b0010111,
//    JAL    = 7'b1101111,
//    JALR   = 7'b1100111,
//    BRANCH = 7'b1100011,
//    LOAD   = 7'b0000011,
//    STORE  = 7'b0100011,
//    OP_IMM = 7'b0010011,
//    OP_REG = 7'b0110011,
//    SYSTEM = 7'b1110011
//} opcode_t;

//typedef enum logic [2:0] {
//    //BRANCH labels
//    BEQ = 3'b000,
//    BNE = 3'b001,
//    BLT = 3'b100,
//    BGE = 3'b101,
//    BLTU = 3'b110,
//    BGEU = 3'b111
//} func3_branch_t;

//// FUNC3 values for I- and R- type instructions that 
//// perform an ALU operation. 
//typedef enum logic [2:0] {
//    OP_SUM  = 3'b000, // ADD, ADDI, SUB 
//    OP_SLL  = 3'b001,
//    OP_SLT  = 3'b010,
//    OP_SLTU = 3'b011,
//    OP_XOR  = 3'b100,
//    OP_SR   = 3'b101, // SRL, SRLI, SRA, SRAI
//    OP_OR   = 3'b110,
//    OP_AND  = 3'b111
//} func3_op_t;


//////////////////////////////////
/* Control Signal utility types */
//////////////////////////////////

//typedef struct packed {
//    logic dmem_rd_en;
//    logic dmem_wr_en;
//    logic [1:0] dmem_size;
//    logic dmem_sign;
//} dmem_ctrl_t;


/* One-hot coded ALU control signal */
//typedef struct packed {
//    logic lui; // load upper immediate alu_fun_t[10]
//    logic sra; // alu_fun_t[9] shift right arithmetic 
//    logic sub;
//    logic fun_and;
//    logic fun_or;
//    logic srl; // shift right logical
//    logic fun_xor;
//    logic sltu; //set less than unsigned
//    logic slt; // set less than
//    logic sll;  // shift left logical
//    logic add; // alu_fun_t[0]

//} alu_fun_t;

`endif
