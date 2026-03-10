`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08.03.2026 19:48:50
// Design Name: 
// Module Name: if_id_registers
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


module if_id_registers #(
  parameter RESET_ADDR = 32'h00000000,
  parameter NOP_INSTRUCTION = 32'h00000013
) (
  input  wire        i_clk,
  input  wire        halt,
  input  wire        if_flush,
  input  wire        write_en,
  
  input  wire [31:0] i_instr,
  input  wire [31:0] i_pc,
  
  output wire [31:0] o_instr,
  output wire [31:0] o_pc
);
  
  reg [31:0] instr = NOP_INSTRUCTION;
  reg [31:0] pc = RESET_ADDR;
  
  assign o_instr = instr;
  assign o_pc = pc;

  always @(posedge i_clk) begin
    casez ({halt, if_flush, write_en})
      3'b1?? : begin
        instr <= NOP_INSTRUCTION;
      end
      3'b01? : begin
        instr <= NOP_INSTRUCTION;
        pc <= i_pc;
      end
      3'b001 : begin
        instr <= i_instr;
        pc <= i_pc;
      end
      default : begin
        instr <= instr;
        pc <= pc;
      end
    endcase
	end
endmodule
