///////////////////////////////////////////////
// Filename:  instr_decoder.sv
// Author: Christopher Tinker
// Date: 2022-01-31
//
// Description:
// 	Opcode decoder for 5-stage in-order
// RV32I pipeline
///////////////////////////////////////////////

//`default_nettype none
`include "util.sv"
`include "instr_formats.svh"

module instr_decoder (
        // Instruction fields
        input [6:0] opcode_i, // ir[6:0]
        input [2:0] func3_i,  // ir[14:12]
        input [0:0] func7_i,  // ir[30]
               
        // ALU Control
        output logic [10:0] alu_fun_o,       // One-hot encoded ALU control signal
        output logic [0:0]  alu_op1_sel_o, // ALU operand 1 selection (before forwarding)
        output logic [1:0]  alu_op2_sel_o, // ALU operand 2 selection (before forwarding)
        
        // Register File Control
        output logic reg_wr_en_o,        // WB-stage register file write enable
        output logic [1:0] reg_wr_sel_o, // Register file write data selection control
        
        // DMEM/LSU Control - TEMP until AXI-Lite implemented
        output logic dmem_rd_en_o,      // Data memory read enable
        output logic dmem_wr_en_o,      // Data memory write enable
        
        // PC Control
        output logic instr_jalr_o,
        output logic instr_jal_o,
        output logic instr_branch_o
        // Forwarding control
        //output logic rs1_used_o,
        //output logic rs2_used_o
    );
    // Operand size and sign extension for load/store instructions is always func3
    //assign dmem_size_o = func3_i[1:0];
    //assign dmem_sign_o = func3_i[2];
    
    
    always_comb begin : decode_instr
        // Initialize outputs to 0
        alu_fun_o      = '0;
        alu_op1_sel_o  = '0;
        alu_op2_sel_o  = '0;
        reg_wr_en_o    = 1'b0;
        reg_wr_sel_o   = '0;
        dmem_rd_en_o   = 1'b0;
        dmem_wr_en_o   = 1'b0;
        
        unique case (opcode_i)
            `LUI: begin                
                reg_wr_en_o   = 1'b1;
                reg_wr_sel_o  = 2'b00;
                alu_fun_o     = `ALU_LUI;
                alu_op1_sel_o = 1'b1;  // U-type Immediate
                alu_op2_sel_o = 2'b00; // Don't care
            end
            
            `AUIPC: begin                
                reg_wr_en_o   = 1'b1;
                reg_wr_sel_o  = 2'b00;
                alu_fun_o     = `ALU_ADD;
                alu_op1_sel_o = 1'b1;  // U-type Immediate
                alu_op2_sel_o = 2'b11; // PC
            end
            
            `JAL: begin
                instr_jal_o  = 1'b1;                
                reg_wr_en_o  = 1'b1;
                reg_wr_sel_o = 2'b10; // PC + 4
            end
            
            `JALR: begin
                instr_jalr_o = 1'b1;                
                reg_wr_en_o  = 1'b1;
                reg_wr_sel_o = 2'b10; // PC + 4     
            end
            
            `BRANCH: begin
                instr_branch_o = 1'b1;
                
                // Pass func3 to EX unmodified?
                // Depends on where branch condition is generated
            end
            
            `LOAD: begin                
                dmem_rd_en_o = 1'b1; // All loads read from memory!
                reg_wr_en_o  = 1'b1;
                reg_wr_sel_o = 2'b01; // Memory Access result
                
                // ARADDR generation with ALU
                alu_fun_o     = `ALU_ADD;
                alu_op1_sel_o = 1'b0; // rd_rs1
                alu_op2_sel_o = 2'b01; // I-type immediate
                
            end
            
            `STORE:  begin                
                dmem_wr_en_o = 1'b1;
                reg_wr_en_o  = 1'b0;
                
                // AWADDR generation with ALU
                alu_fun_o     = `ALU_ADD;
                alu_op1_sel_o = 1'b0;  // rd_rs1
                alu_op2_sel_o = 2'b10; // S-type immediate
            end
            
            `OP_IMM: begin
                reg_wr_en_o   =  1'b1;
                reg_wr_sel_o  = 2'b00; // ALU result
                alu_op1_sel_o = 1'b0;  // rd_rs1
                alu_op2_sel_o = 2'b01; // I-type immediate
                
                // Decode ALU function from func3 field
                unique case (func3_i)
                    `OP_SUM:  alu_fun_o = `ALU_ADD; // ADDI
                    `OP_SLL:  alu_fun_o = `ALU_SLL; // SLLI
                    `OP_SLT:  alu_fun_o = `ALU_SLT; // SLTI
                    `OP_SLTU: alu_fun_o = `ALU_SLTU; //SLTIU
                    `OP_XOR:  alu_fun_o = `ALU_XOR; // XORI
                    `OP_OR:   alu_fun_o = `ALU_OR; // ORI
                    `OP_AND:  alu_fun_o = `ALU_AND; // ANDI
                    
                    `OP_SR: begin // SRLI or SRAI - use func7 to determine which
                        if (func7_i) alu_fun_o = `ALU_SRA; // SRAI
                        else         alu_fun_o = `ALU_SRL; // SRLI      
                    end 
                    
                    default:
                        alu_fun_o = '0;
                endcase
            end
            
            `OP_REG: begin                
                reg_wr_en_o   =  1'b1;
                reg_wr_sel_o  = 2'b00; // ALU result
                alu_op1_sel_o = 1'b0;  // rd_rs1
                alu_op2_sel_o = 2'b00; // rd_rs2
                
                // Decode ALU function from func3 field
                unique case (func3_i)
                    `OP_SLL:  alu_fun_o = `ALU_SLL; // SLL
                    `OP_SLT:  alu_fun_o = `ALU_SLT; // SLT
                    `OP_SLTU: alu_fun_o = `ALU_SLTU; //SLTU
                    `OP_XOR:  alu_fun_o = `ALU_XOR; // XOR
                    `OP_OR:   alu_fun_o = `ALU_OR; // OR
                    `OP_AND:  alu_fun_o = `ALU_AND; // AND
                    
                    `OP_SUM: begin // ADD or SUB - use func7 to determine which
                        if (func7_i) alu_fun_o = `ALU_SUB; // SUB
                        else         alu_fun_o = `ALU_ADD; // ADD
                    end
                    
                    `OP_SR: begin // SRL or SRA - use func7 to determine which
                        if (func7_i) alu_fun_o = `ALU_SRA; // SRA
                        else         alu_fun_o = `ALU_SRL; // SRL    
                    end 
                    
                    default: alu_fun_o = '0;
                endcase
            end
            
            `SYSTEM: begin
                // TODO: MRET, ECALL, FENCE, ZiCSR
            end
                
            default: begin
                // TODO: throw illegal instruction exception
            end
        endcase      
    end
    
    
`ifdef FORMAL
    always_comb begin
        // alu_fun_o can be either one-hot encoded or all zero, nothing else
        alu_fun_onehot: assert($onehot(alu_fun_o) || alu_fun_o == '0);
        
        // Instruction opcode output can be either one-hot or zero (in case of illegal instruction)
        instr_opcode_onehot: assert($onehot(instr_opcode) || instr_opcode == '0);
        
        // Assert that if instr_opcode is 0, illegal instruction detected (some decode_instr_err_o signal)

        // Assert that dmem_wr_en and dmem_rd_en are never asserted together
        dmem_en_concurrency: assert(!(dmem_rd_en && dmem_wr_en));
    end
`endif

endmodule