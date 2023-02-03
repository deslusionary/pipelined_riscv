///////////////////////////////////////////////
// Filename:  reg_file.sv
// Author: Christopher Tinker
// Date: 2022-01-30
//
// Description:
// 	2 read port, 1 write port register file for an
// in-order RV32 processor. Asynchronous read, 
// synchronous (negedge triggered) write.
///////////////////////////////////////////////


module reg_file (
        input               clk,
        input [4:0]         rd_addr1_i,
        input [4:0]         rd_addr2_i,
        input [4:0]         wr_addr_i,
        input [31:0]        wr_data_i,
        input               wr_en_i,
        output logic [31:0] rd_rs1_o,
        output logic [31:0] rd_rs2_o
    );

    logic [31:0] regs [31:0];

    initial begin
        for (integer i = 0; i < 32; i++) begin
            regs[i] = 32'b0;
        end
    end

    // Negedge-triggered synchronous write
    always_ff @(negedge clk) begin
        if (wr_en_i && wr_addr_i != '0) begin
            regs[wr_addr_i] <= wr_data_i;
        end
    end

    // Asynchronous read ports
    assign rd_rs1_o = (rd_addr1_i == '0) ? 32'b0 : regs[rd_addr1_i];
    assign rd_rs2_o = (rd_addr2_i == '0) ? 32'b0 : regs[rd_addr2_i];

endmodule
