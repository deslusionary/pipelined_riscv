///////////////////////////////////////////////
// Filename:  core_riscv.sv
// Author: Christopher Tinker
// Date: 2022-02-04
//
// Description:
// 	Top-level module for 5 stage pipelined RV32I core
///////////////////////////////////////////////

`include "util.sv"

module core_riscv (
    input logic         clk,
    input logic         rst_i,

    // IMEM Interface
    input  logic [31:0] imem_data_i,
    output logic [31:0] imem_addr_o,
    output logic        imem_rd_en_o,

    // DMEM Interface
    input  logic [31:0] dmem_data_i,
    output logic [31:0] dmem_data_o,
    output logic [31:0] dmem_addr_o,
    output logic        dmem_rd_en_o,
    output logic        dmem_wr_en_o,
    output logic [1:0]  dmem_size_o,
    output logic        dmem_sign_o
);

    /* Signal Declarations */
    // Un-registered control flags from ID to IF
    logic instr_jal;
    logic instr_jalr;
    logic branch_taken;
    // Pass JAL/JALR/BRANCH target address from ID to IF
    logic [31:0] jal_addr;
    logic [31:0] jalr_addr;
    logic [31:0] branch_addr;

    // Inter-stage pipeline register wires
    if_id_reg_t if_id_reg;
    id_ex_reg_t id_ex_reg;
    ex_ma_reg_t ex_ma_reg;
    ma_wb_reg_t ma_wb_reg;

    // WB and Register file Signals
    logic        wb_reg_wr_en;
    logic [31:0] wb_reg_wr_data;
    logic [4:0]  wb_reg_wr_addr;
    logic [31:0] data_rs1;
    logic [31:0] data_rs2;


    ///////////////////////////////
    /* Instruction Fetch         */
    ///////////////////////////////

    stage_fetch fetch (
        .clk            (clk),
        .rst_i          (rst_i),
        .stall_i        (1'b0),
        .squash_i       (1'b0),
        .instr_jal_i    (instr_jal),
        .instr_jalr_i   (instr_jalr),
        .branch_taken_i (branch_taken),
        .jal_addr_i     (jal_addr),
        .jalr_addr_i    (jalr_addr),
        .branch_addr_i  (branch_addr),

        .imem_addr_o    (imem_addr_o),  // IMEM interface
        .imem_rd_en_o   (imem_rd_en_o), // IMEM interface
        .if_id_reg_o    (if_id_reg)    // IF-ID pipeline register
    );


    ///////////////////////////////
    /* Instruction Decode        */
    ///////////////////////////////

    stage_decode decode (
        .clk            (clk),
        .rst_i          (rst_i),
        .stall_i        (1'b0),
        .squash_i       (1'b0),
        .instr_i        (imem_data_i), // Pass instruction memory output directly to ID
        .if_id_i        (if_id_reg),   // IF-ID pipeline register in
        .data_rs1_i     (data_rs1),
        .data_rs2_i     (data_rs2),

        .id_ex_reg_o    (id_ex_reg),  // ID-EX pipeline register
        .instr_jal_o    (instr_jal),
        .instr_jalr_o   (instr_jalr),
        .branch_taken_o (branch_taken),
        .jal_addr_o     (jal_addr),
        .jalr_addr_o    (jalr_addr),
        .branch_addr_o  (branch_addr)
    );


    ///////////////////////////////
    /* Execute                   */
    ///////////////////////////////

    stage_ex ex (
        .clk         (clk),
        .rst_i       (rst_i),
        .stall_i     (1'b0),
        .squash_i    (1'b0),
        .id_ex_i     (id_ex_reg), // ID-EX pipeline register

        .ex_ma_reg_o (ex_ma_reg)  // EX-MA pipeline register
    );

    
    ///////////////////////////////
    /* Memory Access             */
    ///////////////////////////////

    /* The stage_ma module doesn't do anything beside
     * control the MA-WB pipeline register. Actual control 
     * of memory access is done with signals generated in
     * the ID and EX stages.
     */
    stage_ma ma (
        .clk         (clk),
        .rst_i       (rst_i),
        .stall_i     (1'b0),
        .squash_i    (1'b0),
        .ex_ma_i     (ex_ma_reg), // EX-MA pipeline register

        .ma_wb_reg_o (ma_wb_reg) // MA-WB pipeline register
    );

    // Provide DMEM control signals on core outputs
    // ALU is used to compute load/store addresses - 
    // a future rev will likely have a dedicated Load/Store Unit
    assign dmem_rd_en_o = ex_ma_reg.dmem_rd_en; // DMEM read enable
    assign dmem_wr_en_o = ex_ma_reg.dmem_wr_en; // DMEM write enable
    assign dmem_addr_o  = ex_ma_reg.alu_result; // DMEM address
    assign dmem_data_o  = ex_ma_reg.dmem_data;  // DMEM write data
    assign dmem_size_o  = ex_ma_reg.dmem_size;  // byte / halfword / word
    assign dmem_sign_o  = ex_ma_reg.dmem_sign;  // Signed or unsigned data


    ///////////////////////////////
    /* Register Writeback        */
    ///////////////////////////////

    /* Register File Write Enable
     * If an instruction has been marked invalid,
     * it must not change register file state!
     */
    // TODO: add support for hazard unit SQUASH here
    assign wb_reg_wr_en = (ma_wb_reg.instr_valid && ma_wb_reg.reg_wr_en) ? 1'b1 : 1'b0;
    
    assign wb_reg_wr_addr = ma_wb_reg.reg_wr_addr; // rd RISCV field - instr[11:7]

    // Select data to write to register file
    always_comb begin
        unique case (ma_wb_reg.reg_wr_sel)
        2'b00: wb_reg_wr_data = ma_wb_reg.alu_result; // ALU result
        2'b01: wb_reg_wr_data = dmem_data_i;          // Byte-aligned and sign-extended DMEM output
        2'b10: wb_reg_wr_data = ma_wb_reg.pc_plus_four; // JAL/JALR return address write
        2'b11: wb_reg_wr_data = '0; // RFU for CSR writes to register file

        default: wb_reg_wr_data = '0; // Shouldn't even need this default /shrug
        endcase
    end
    

    ///////////////////////////////
    /* Register File             */
    ///////////////////////////////

    reg_file core_reg_file (
        .clk        (clk),
        .rd_addr1_i (imem_data_i[19:15]), // RISCV rs1 field 
        .rd_addr2_i (imem_data_i[24:20]), // RISCV rs2 field
        .wr_addr_i  (wb_reg_wr_addr), // rd value from MA-WB pipeline register
        .wr_data_i  (wb_reg_wr_data),
        .wr_en_i    (wb_reg_wr_en),

        .rd_rs1_o   (data_rs1),
        .rd_rs2_o   (data_rs2)
    );

    ///////////////////////////////
    /* Hazard Control            */
    ///////////////////////////////

    // Massive TODO here -- also forwarding units!

`ifdef FORMAL
`endif
    
endmodule
