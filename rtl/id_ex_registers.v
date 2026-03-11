`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09.03.2026 03:24:00
// Design Name: 
// Module Name: id_ex_registers
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


module id_ex_registers #(
  parameter RESET_ADDR = 32'h00000000,
  parameter NOP_INSTRUCTION = 32'h00000013
) (
  input  wire        i_clk,
  input  wire        i_rst,
  
  input  wire [31:0] i_instr,
  input  wire [31:0] i_pc,
  input  wire [31:0] i_next_pc,
  
  input  wire        id_flush,
  input  wire        cu_passthrough_en,
  input  wire        i_is_halting,

  input  wire [31:0] i_rs1_data,
  input  wire [31:0] i_rs2_data,
  
  // Control Unit wires
  // Execute stage control
  input  wire [31:0] i_imm_val,
  input  wire        i_pc_add, // 0 for rs1_data, 1 for PC
  input  wire        i_alu_src, // 0 for rs2_data, 1 for immediate
  input  wire [ 4:0] i_alu_opsel, // ALU Control Signal
  // Memory stage/Data Memory control
  input  wire        i_dmem_read_en, // i_id_ex_mem_read
  input  wire        i_dmem_write_en,
  input  wire [ 2:0] i_funct3,
  // Writeback stage Control
  input  wire        i_reg_write_en, // Regiser File control, i_id_ex_reg_write
  input  wire [ 1:0] i_register_write_sel, 

  input wire i_is_retiring,
  
  output reg  [31:0] o_instr = NOP_INSTRUCTION,
  output reg  [31:0] o_pc = RESET_ADDR,
  output reg  [31:0] o_next_pc = RESET_ADDR + 4,
  
  output reg         o_is_halting,

  
  // Register data
  output reg  [31:0] o_rs1_data,
  output reg  [31:0] o_rs2_data,
  
  // Control Unit wires
  output reg        keep_halting = 1'b0,
  // Execute stage control
  output reg  [31:0] o_imm_val,
  output reg         o_pc_add, // 0 for rs1_data, 1 for PC
  output reg         o_alu_src, // 0 for rs2_data, 1 for immediate
  output reg  [ 4:0] o_alu_opsel, // ALU Control Signal
  // Memory stage/Data Memory control
  output reg         o_dmem_read_en,
  output reg         o_dmem_write_en,
  output reg  [ 2:0] o_funct3,
  // Writeback stage control
  output reg         o_reg_write_en, // Regiser File control
  output reg  [ 1:0] o_register_write_sel,
  
  output reg         o_is_retiring
);
  
  initial begin
    keep_halting <= 1'b0;
  end
  
  always @(posedge i_clk) begin
    keep_halting <= i_rst == 1'b1 ? 0 : i_is_halting;
    o_is_halting <= i_rst == 1'b1 ? 0 : i_is_halting;

    if (id_flush | (~cu_passthrough_en & ~i_rst) | i_rst) begin
      o_instr <= NOP_INSTRUCTION;
      o_pc <= i_rst == 1'b1 ? RESET_ADDR : o_pc;
      o_next_pc <= i_rst == 1'b1 ? RESET_ADDR + 4: o_next_pc;
            
      o_rs1_data <= 32'd0;
      o_rs2_data <= 32'd0;
    
      o_imm_val <= 32'd0;
      o_pc_add <= 1'b0;
      o_alu_src <= 1'b0;
      o_alu_opsel <= 5'd0;

      o_dmem_read_en <= 1'b0;
      o_dmem_write_en <= 1'b0;
      o_funct3 <= 3'd0;

      o_reg_write_en <= 1'b0;
      o_register_write_sel <= 2'd0;
      
      o_is_retiring <= 1'b0;
    end else begin
      o_instr <= i_instr;
      o_pc <= i_pc;
      o_next_pc <= i_next_pc;
      
      o_rs1_data <= i_rs1_data;
      o_rs2_data <= i_rs2_data;
    
      o_imm_val <= i_imm_val;
      o_pc_add <= i_pc_add;
      o_alu_src <= i_alu_src;
      o_alu_opsel <= i_alu_opsel;

      o_dmem_read_en <= i_dmem_read_en;
      o_dmem_write_en <= i_dmem_write_en;
      o_funct3 <= i_funct3;

      o_reg_write_en <= i_reg_write_en;
      o_register_write_sel <= i_register_write_sel;
      
      //basicially in our trace we were always retiring a nop at first
      o_is_retiring <= (i_instr != 32'h00000013);
    end
  end

endmodule
