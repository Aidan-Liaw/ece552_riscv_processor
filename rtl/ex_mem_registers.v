`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09.03.2026 04:13:53
// Design Name: 
// Module Name: ex_mem_registers
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


module ex_mem_registers #(
  parameter RESET_ADDR = 32'h00000000,
  parameter NOP_INSTRUCTION = 32'h00000013
) (
  input  wire        i_clk,
  input  wire        i_rst,
  
  input  wire [31:0] i_instr,
  input  wire [31:0] i_pc,
  input  wire [31:0] i_next_pc,
  
  input  wire        ex_flush,
  input  wire        i_is_halting,

  input  wire [31:0] i_rs1_data,
  input  wire [31:0] i_rs2_data,
  
  input wire  [31:0] i_alu_result,
  
  // Control Unit wires
  // Memory stage/Data Memory control
  input  wire        i_dmem_read_en,
  input  wire        i_dmem_write_en,
  input  wire [ 2:0] i_funct3,
  // Writeback stage
  input  wire [31:0] i_imm_val,
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
  
  output reg  [31:0] o_alu_result,

  
  // Control Unit wires
  // Memory stage/Data Memory control
  output reg         o_dmem_read_en,
  output reg         o_dmem_write_en,
  output reg  [ 2:0] o_funct3,
  // Writeback stage
  output reg  [31:0] o_imm_val,
  output reg         o_reg_write_en, // Regiser File control
  output reg  [ 1:0] o_register_write_sel,
  
  output reg         o_is_retiring
);

  always @(posedge i_clk) begin
    o_is_halting <= i_is_halting;

    if (ex_flush | i_rst) begin
      o_instr <= NOP_INSTRUCTION;
      o_pc <= i_rst == 1'b1 ? RESET_ADDR : o_pc;
      o_next_pc <= i_rst == 1'b1 ? RESET_ADDR + 4: o_next_pc;
      
      o_rs1_data <= 32'd0;
      o_rs2_data <= 32'd0;
      
      o_alu_result <= 32'd0;

      o_dmem_read_en <= 1'b0;
      o_dmem_write_en <= 1'b0;
      o_funct3 <= 3'd0;

      o_imm_val <= 32'd0;
      o_reg_write_en <= 1'b0;
      o_register_write_sel <= 2'd0;
      
      o_is_retiring <= 1'b0;
    end else begin
      o_instr <= i_instr;
      o_pc <= i_pc;
      o_next_pc <= i_next_pc;
      
      o_rs1_data <= i_rs1_data;
      o_rs2_data <= i_rs2_data;
      
      o_alu_result <= i_alu_result;

      o_dmem_read_en <= i_dmem_read_en;
      o_dmem_write_en <= i_dmem_write_en;
      o_funct3 <= i_funct3;

      o_imm_val <= i_imm_val;
      o_reg_write_en <= i_reg_write_en;
      o_register_write_sel <= i_register_write_sel;
      
      o_is_retiring <= i_is_retiring;
    end
  end
endmodule
