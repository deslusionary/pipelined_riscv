///////////////////////////////////////////////
// Filename:  core_tb.sv
// Author: Christopher Tinker
// Date: 2022-02-04
//
// Description:
// 	Quick bringup testbench for pipelined RV32I core
///////////////////////////////////////////////

module core_tb (
    );
    
    logic clk = 0;
    logic rst = 0;

    logic [31:0] imem_data;
    logic [31:0] imem_addr;
    logic        imem_rd_en;

    logic [31:0] dmem_wr_data;
    logic [31:0] dmem_rd_data;
    logic [31:0] dmem_addr;
    logic [1:0]  dmem_size;
    logic        dmem_sign;
    logic        dmem_wr_en;
    logic        dmem_rd_en;

    core_riscv dut (
        .clk          (clk),
        .rst_i        (rst),

        .imem_data_i  (imem_data),
        .imem_addr_o  (imem_addr),
        .imem_rd_en_o (imem_rd_en),

        .dmem_data_i  (dmem_rd_data),
        .dmem_data_o  (dmem_wr_data),
        .dmem_addr_o  (dmem_addr),
        .dmem_rd_en_o (dmem_rd_en),
        .dmem_wr_en_o (dmem_wr_en),
        .dmem_size_o  (dmem_size),
        .dmem_sign_o  (dmem_sign)
    );

    bram_dualport mem (
        .MEM_CLK    (clk),
        .MEM_ADDR1  (imem_addr),
        .MEM_ADDR2  (dmem_addr),
        .MEM_DIN2   (dmem_wr_data),
        .MEM_WRITE2 (dmem_wr_en),
        .MEM_READ1  (imem_rd_en),
        .MEM_READ2  (dmem_wr_en),
        .ERR        (),
        .MEM_DOUT1  (imem_data),
        .MEM_DOUT2  (dmem_rd_data),
        .IO_IN      ('0),
        .IO_WR      (),
        .MEM_SIZE   (dmem_size),
        .MEM_SIGN   (dmem_sign)
    );

    initial begin
        rst = 1'b1;
        #20
        rst = 1'b0;
        #500
        $finish;
    end

    always #5 begin
        clk <= ~clk;
    end
endmodule