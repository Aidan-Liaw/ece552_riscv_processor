`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09.03.2026 04:40:59
// Design Name: 
// Module Name: mem_wb_registers
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module mem_wb_registers #(
  parameter RESET_ADDR = 32'h00000000,
  parameter NOP_INSTRUCTION = 32'h00000013
) (
  input  wire        i_clk,
  input  wire        i_rst,
  
  input  wire [31:0] i_instr,
  input  wire [31:0] i_pc,
  input  wire [31:0] i_next_pc,
  
  input  wire        mem_flush,
  input  wire        i_is_halting,

  input  wire [31:0] i_rs1_data,
  input  wire [31:0] i_rs2_data,

  
  // Control Unit wires
  // Memory stage
  input  wire [31:0] i_retire_dmem_addr,
  input  wire        i_retire_dmem_ren,
  input  wire        i_retire_dmem_wen,
  input  wire [ 3:0] i_retire_dmem_mask,
  input  wire [31:0] i_retire_dmem_wdata,
  input  wire [31:0] i_retire_dmem_rdata,
  
  
  // Writeback stage
  input  wire [31:0] i_alu_result,
  input  wire [31:0] i_imm_val,
  input  wire [31:0] i_dmem_data,
  input  wire        i_reg_write_en, // Regiser File control
  input  wire [ 1:0] i_register_write_sel, 
  
  input  wire        i_is_retiring,

  
  output reg  [31:0] o_instr = NOP_INSTRUCTION,
  output reg  [31:0] o_pc = RESET_ADDR,
  output reg  [31:0] o_next_pc = RESET_ADDR + 4,
  
  output reg         o_is_halting,

  
  // Register data
  output reg  [31:0] o_rs1_data,
  output reg  [31:0] o_rs2_data,
  
  
  // Control Unit wires
  // Memory stage
  output reg [31:0] o_retire_dmem_addr,
  output reg        o_retire_dmem_ren,
  output reg        o_retire_dmem_wen,
  output reg [ 3:0] o_retire_dmem_mask,
  output reg [31:0] o_retire_dmem_wdata,
  output reg [31:0] o_retire_dmem_rdata,
  
  // Writeback stage
  output reg  [31:0] o_alu_result,
  output reg  [31:0] o_imm_val,
  output reg  [31:0] o_dmem_data,
  output reg         o_reg_write_en, // Regiser File control
  output reg  [ 1:0] o_register_write_sel,
  
  output reg         o_is_retiring
);

  always @(posedge i_clk) begin
    o_is_halting <= i_is_halting;

    if (mem_flush | i_rst) begin
      o_instr <= NOP_INSTRUCTION;
      o_pc <= i_rst == 1'b1 ? RESET_ADDR : o_pc;
      o_next_pc <= i_rst == 1'b1 ? RESET_ADDR + 4: o_next_pc;
      
      o_rs1_data <= 32'd0;
      o_rs2_data <= 32'd0;
      
      o_retire_dmem_addr <= 32'd0;
      o_retire_dmem_ren <= 1'b0;
      o_retire_dmem_wen <= 1'b0;
      o_retire_dmem_mask <= 4'd0;
      o_retire_dmem_wdata <= 32'd0;
      o_retire_dmem_rdata <= 32'd0;
      
      o_alu_result <= 32'd0;
      o_imm_val <= 32'd0;
      o_dmem_data <= 32'd0;
      o_reg_write_en <= 1'b0;
      o_register_write_sel <= 2'd0;
      
      o_is_retiring <= 1'b0;
    end else begin
      o_instr = i_instr;
      o_pc = i_pc;
      o_next_pc = i_next_pc;
      
      o_rs1_data <= i_rs1_data;
      o_rs2_data <= i_rs2_data;
      
      o_retire_dmem_addr <= i_retire_dmem_addr;
      o_retire_dmem_ren <= i_retire_dmem_ren;
      o_retire_dmem_wen <= i_retire_dmem_wen;
      o_retire_dmem_mask <= i_retire_dmem_mask;
      o_retire_dmem_wdata <= i_retire_dmem_wdata;
      o_retire_dmem_rdata <= i_retire_dmem_rdata;
      
      o_alu_result <= i_alu_result;
      o_imm_val <= i_imm_val;
      o_dmem_data <= i_dmem_data;
      o_reg_write_en <= i_reg_write_en;
      o_register_write_sel <= i_register_write_sel;
      
      o_is_retiring <= i_is_retiring;
    end
  end
endmodule
