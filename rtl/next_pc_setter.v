`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08.03.2026 21:33:11
// Design Name: 
// Module Name: next_pc_setter
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


module next_pc_setter(
  input  wire [31:0] i_pc,
  
  input  wire [6:0]  opcode,
  input  wire        is_branch_taken,
  input  wire        is_jump_taken,
  input  wire [31:0] register_jump_target,
  input  wire [31:0] immediate_jump_target,
  
  output wire [31:0] next_pc
);
    
  localparam JALR_OPCODE = 7'b1100111;
  // IF opcode == 7'b1100111 THEN
  //    jalr jump 
  // ELSE 
  //    jal jump 
  // END IF
  // Remember that 1b shift is done in Immediate Generator, so no need to do it here.
	wire [31:0] jump_target = (opcode == JALR_OPCODE) ? register_jump_target : immediate_jump_target;
	// IF jump OR branch condition valid THEN
	//   next_pc = jump_target
	// ELSE
	//   next_pc = pc_reg + 4
	// END IF
  // None of these logical operators are permitted.
	// We will need to rewrite all of this as massive ternary statements
	assign next_pc = (is_jump_taken | is_branch_taken) ? jump_target : (i_pc + 4);
endmodule
