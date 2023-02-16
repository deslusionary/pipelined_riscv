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
    id_ex_reg_t id_ex_reg, id_ex_forwarded;
    ex_ma_reg_t ex_ma_reg;
    ma_wb_reg_t ma_wb_reg;

    // WB and Register file Signals
    logic        wb_reg_wr_en;
    logic [31:0] wb_data;
    logic [4:0]  wb_reg_wr_addr;
    logic [31:0] data_rs1;
    logic [31:0] data_rs2;

    // Forwarding Control
    logic forward_ex_ma_valid;
    logic forward_ma_wb_valid;

    // Hazard Control
    logic squash_if;
    logic squash_id;
    logic squash_ex;
    logic squash_ma;
    logic squash_wb;

    logic stall_if;
    logic stall_id;
    logic stall_ex;
    logic stall_ma;
    logic stall_wb;

    ///////////////////////////////
    /* Instruction Fetch         */
    ///////////////////////////////

    stage_fetch fetch (
        .clk            (clk),
        .rst_i          (rst_i),
        .stall_i        (stall_if),
        .squash_i       (squash_if),
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
        .stall_i        (stall_id),
        .squash_i       (squash_id),
        .instr_i        (imem_data_i), // Pass instruction memory output directly to ID
        .if_id_i        (if_id_reg),   // IF-ID pipeline register in
        .data_rs1_i     (data_rs1),
        .data_rs2_i     (data_rs2),

        .id_ex_reg_o    (id_ex_reg),  // ID-EX pipeline register
        .instr_jal_o    (instr_jal),
        .jal_addr_o     (jal_addr)
    );


    ///////////////////////////////
    /* Execute                   */
    ///////////////////////////////

    stage_ex ex (
        .clk            (clk),
        .rst_i          (rst_i),
        .stall_i        (stall_ex),
        .squash_i       (squash_ex),
        .id_ex_i        (id_ex_forwarded), // ID-EX pipeline register

        .ex_ma_reg_o    (ex_ma_reg),  // EX-MA pipeline register
        .instr_jalr_o   (instr_jalr),
        .branch_taken_o (branch_taken),
        .jalr_addr_o    (jalr_addr),
        .branch_addr_o  (branch_addr)
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
        .stall_i     (stall_ma),
        .squash_i    (squash_ma),
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
    assign wb_reg_wr_en = (ma_wb_reg.valid && ma_wb_reg.reg_wr_en && !squash_wb) ? 1'b1 : 1'b0;
    
    assign wb_reg_wr_addr = ma_wb_reg.reg_wr_addr; // rd RISCV field - instr[11:7]

    // Select data to write to register file
    always_comb begin
        unique case (ma_wb_reg.reg_wr_sel)
        2'b00: wb_data = ma_wb_reg.alu_result; // ALU result
        2'b01: wb_data = dmem_data_i;          // Byte-aligned and sign-extended DMEM output
        2'b10: wb_data = ma_wb_reg.pc_plus_four; // JAL/JALR return address write
        2'b11: wb_data = '0; // RFU for CSR writes to register file

        default: wb_data = '0; // Shouldn't even need this default /shrug
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
        .wr_data_i  (wb_data),
        .wr_en_i    (wb_reg_wr_en),

        .rd_rs1_o   (data_rs1),
        .rd_rs2_o   (data_rs2)
    );

    ///////////////////////////////
    /* Hazard Control            */
    ///////////////////////////////

    // Massive TODO here -- also forwarding units!
    // TODO: make sure marked invalid jal/jalr/branch don't change PC
    // Load/use interlock
    // JAL/use interlock
    // Cache miss stall
    // Control flow penalty

    always_comb begin
        squash_if = 1'b0;
        squash_id = 1'b0;
        squash_ex = 1'b0;
        squash_ma = 1'b0;
        squash_wb = 1'b0;

        stall_if = 1'b0;
        stall_id = 1'b0;
        stall_ex = 1'b0;
        stall_ma = 1'b0;
        stall_wb = 1'b0;

        // 2 cycle JALR/BRANCH penalty
        if (instr_jalr || branch_taken) begin
            squash_if = 1'b1;
            squash_id = 1'b1;
        end

        // 1 cycle JAL penalty
        if (instr_jal) begin
            squash_if = 1'b1;
        end

        // Load-use interlock
        if ((id_ex_reg.rs1_used || id_ex_reg.rs2_used)
            && ex_ma_reg.dmem_rd_en 
            && ex_ma_reg.valid
            && (ex_ma_reg.reg_wr_addr == id_ex_reg.rs1_addr 
                || ex_ma_reg.reg_wr_addr == id_ex_reg.rs2_addr)) begin
            
            stall_if  = 1'b1;
            stall_id  = 1'b1;
            squash_ex = 1'b1;
        end

        // JAL-use interlock

    end

    //////////////////////////////
    /* Forwarding Control       */
    //////////////////////////////

    always_comb begin
        id_ex_forwarded     = id_ex_reg;
        forward_ex_ma_valid = (ex_ma_reg.valid && ex_ma_reg.reg_wr_en);
        forward_ma_wb_valid = (ma_wb_reg.valid && ma_wb_reg.reg_wr_en);

        // rs1 forwarding
        if (id_ex_reg.rs1_used && forward_ex_ma_valid 
                && (id_ex_reg.rs1_addr == ex_ma_reg.reg_wr_addr)) begin
            id_ex_forwarded.alu_op1 = ex_ma_reg.alu_result;
        end

        else if (id_ex_reg.rs1_used && forward_ma_wb_valid 
                && (id_ex_reg.rs1_addr == ma_wb_reg.reg_wr_addr)) begin
            id_ex_forwarded.alu_op1 = wb_data;  
        end

        else begin
            id_ex_forwarded.alu_op1 = id_ex_reg.alu_op1;
        end

        // rs2 forwarding
        // Need extra check to forward to dmem_data instead of alu_op2
        // if instruction is a store
        if (id_ex_reg.rs2_used && forward_ex_ma_valid
                && (id_ex_reg.rs2_addr == ex_ma_reg.reg_wr_addr)) begin
            
            if (id_ex_reg.dmem_wr_en) id_ex_forwarded.dmem_data = ex_ma_reg.alu_result;
            else                      id_ex_forwarded.alu_op2   = ex_ma_reg.alu_result;
        end

        else if (id_ex_reg.rs2_used && forward_ma_wb_valid 
                && (id_ex_reg.rs2_addr == ma_wb_reg.reg_wr_addr)) begin
            
            if (id_ex_reg.dmem_wr_en) id_ex_forwarded.dmem_data = wb_data;
            else                      id_ex_forwarded.alu_op2   = wb_data;
        end

        else begin
            id_ex_forwarded.dmem_data = id_ex_reg.dmem_data;
            id_ex_forwarded.alu_op2   = id_ex_reg.alu_op2;
        end
    end

`ifdef FORMAL
`endif
    
endmodule
