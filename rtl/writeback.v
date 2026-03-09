`timescale 1ns / 1ps

`default_nettype wire

module writeback (
  input  wire  [ 1:0] register_write_sel,
  
  input  wire  [31:0] pc,
  input  wire  [31:0] alu_result,
  input  wire  [31:0] imm_val,
  input  wire  [31:0] dmem_rdata,
  
  output wire  [31:0] writeback_data
);
	
	assign writeback_data = register_write_sel == 2'b00 ? alu_result 
	                      : register_write_sel == 2'b01 ? (pc + 4)
	                      : register_write_sel == 2'b10 ? imm_val
	                      : register_write_sel == 2'b11 ? dmem_rdata //modified to read from read aligner
	                      : 32'd0;

endmodule