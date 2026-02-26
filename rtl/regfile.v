`timescale 1ns / 1ps

`default_nettype none

// The register file is effectively a single cycle memory with 32-bit words
// and depth 32. It has two asynchronous read ports, allowing two independent
// registers to be read at the same time combinationally, and one synchronous
// write port, allowing a register to be written to on the next clock edge.
// The register `x0` is hardwired to zero, and writes to it are ignored.
module regfile #(
    // When this parameter is set to 1, "RF bypass" mode is enabled. This
    // allows data at the write port to be observed at the read ports
    // immediately without having to wait for the next clock edge. This is
    // a common forwarding optimization in a pipelined core (project 5), but
    // will cause a single-cycle processor to behave incorrectly.
    //
    // You are required to implement and test both modes. In project 3 and 4,
    // you will set this to 0, before enabling it in project 5.
    parameter BYPASS_EN = 0
) (
    // Global clock.
    input  wire        clk,
    // Synchronous active-high reset.
    input  wire        rst,
    // Both read register ports are asynchronous (zero-cycle). That is, read
    // data is visible combinationally without having to wait for a clock.
    //
    // Register read port 1, with input address [0, 31] and output data.
    input  wire [ 4:0] rs1_raddr,
    output wire [31:0] rs1_rdata,
    // Register read port 2, with input address [0, 31] and output data.
    input  wire [ 4:0] rs2_raddr,
    output wire [31:0] rs2_rdata,
    // The register write port is synchronous. When write is enabled, the
    // write data is visible after the next clock edge.
    //
    // Write register enable, address [0, 31] and input data.
    input  wire        rd_wen,
    input  wire [ 4:0] rd_waddr,
    input  wire [31:0] rd_wdata
);

reg [1023:0] registers = 1024'd0;
reg [31:0] o_rs1_rdata_reg;
reg [31:0] o_rs2_rdata_reg;

// $clog2(1024) = 10, meaning you need 10 bits to address everything.
// Otherwise there is not enough bits to address all of the memory.
wire [9:0] rs1_raddr_reg = {5'd0, rs1_raddr};
wire [9:0] rs2_raddr_reg = {5'd0, rs2_raddr};
wire [9:0] rd_waddr_reg  = {5'd0,  rd_waddr}; 


// Logic for the assignments are as follows:
// - IF BYPASS_EN == 1 AND write address == read address THEN
// -    output data <= input data
// - ELSE
// -    output data = data at requested register number
// - END IF

assign rs1_rdata = (BYPASS_EN == 1) & (rs1_raddr_reg == rd_waddr_reg) & (rd_waddr_reg != 32'd0) & (rd_wen == 1'b1)
                     ? rd_wdata 
                     : registers[(rs1_raddr_reg << 5) +: 32];
assign rs2_rdata = (BYPASS_EN == 1) & (rs2_raddr_reg == rd_waddr_reg) & (rd_waddr_reg != 32'd0) & (rd_wen == 1'b1)
                     ? rd_wdata 
                     : registers[(rs2_raddr_reg << 5) +: 32]; //read from base address up to 32 bits 
                     
                     

always @(posedge clk) begin
    // IF reset == 1 THEN ALWAYS reset
    // ELSE IF write enable == 1 then write
    // ELSE registers remain unchanged
    // END IF
    casez ({rst, rd_wen})
        2'b1? : registers <= 1024'd0;
        2'b01 : registers[(rd_waddr_reg << 5) +: 32]  <= rd_waddr_reg != 5'd0
                                                      ? rd_wdata
                                                      : registers[(rd_waddr_reg << 5) +: 32];
        default : registers <= registers;
    endcase
end

endmodule

`default_nettype wire