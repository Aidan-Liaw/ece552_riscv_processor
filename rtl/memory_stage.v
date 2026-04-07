`timescale 1ns / 1ps

`default_nettype wire

// Stupid rename due to conflict with TA's module names
module memory_stage (
  input  wire [ 2:0] funct3,
  input  wire [31:0] rs2_data,
  input  wire [31:0] alu_result,
  input  wire        i_dmem_read_en,
  input  wire        i_dmem_write_en,
  
  input  wire        i_dmem_ready,
  input  wire [31:0] i_dmem_rdata,

  output wire [31:0] o_dmem_addr,
  output wire        o_dmem_ren,
  output wire        o_dmem_wen,
  output wire [31:0] o_dmem_wdata,
  output wire [ 3:0] o_dmem_mask,
  
  output wire [31:0] dmem_data
);

	///// mem alignment logic /////
	wire [1:0] addr_align = alu_result[1:0];
	
  wire [3:0]  write_dmem_mask;
  wire [3:0]  read_dmem_mask;
	wire [31:0] dmem_wdata;

	// mem outputs
	// In a real RV32-I, only the LSBit is 0'ed, but since we are no factoring in 
	// the C or Zc* extenstions, this is fine
	assign o_dmem_addr = {alu_result[31:2], 2'b00};
	
	// The write and read enables cannot assert unless the D-Mem 
	// is ready to accept a new request
	assign o_dmem_ren = i_dmem_read_en & i_dmem_ready;
	assign o_dmem_wen = i_dmem_write_en & i_dmem_ready;
	assign o_dmem_wdata = dmem_wdata;
  assign o_dmem_mask = i_dmem_write_en == 1 ? write_dmem_mask : read_dmem_mask;

  write_data_aligner write_data_aligner(addr_align, i_dmem_write_en, 
    funct3, rs2_data, write_dmem_mask, dmem_wdata);
    
    
  read_data_aligner read_data_aligner(addr_align, i_dmem_read_en,
    funct3, i_dmem_rdata, read_dmem_mask, dmem_data);    
    
endmodule