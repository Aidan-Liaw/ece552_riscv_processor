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
  
  input  wire        i_imem_ready,
  input  wire        i_dmem_ready, // Possibly redundant.
  input  wire        instr_buffer_empty, // Possibly redundant.
  input  wire        instr_buffer_full,
  
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
	// IF instr_buffer_full OR (NOT i_imem_ready) OR (NOT i_dmem_ready) THEN
	//   next_pc = pc_reg
	// ELSE IF jump OR branch condition valid THEN
	//   next_pc = jump_target
	// ELSE
	//   next_pc = pc_reg + 4
	// END IF
	// If the buffer is full, do not fetch
	// else if a jump or branch is hapening, go to the target address
	// else increment pc by 4
	// If I-Mem or D-Mem are not ready, then PC cannot increment
	// This is because if I-Mem is not ready and we modify PC, then an address may have been skipped
	// and if D-Mem is not ready then the whole processor must stall, including the PC
    //redirect pc first if control flow change then stall
	assign next_pc = (is_jump_taken | is_branch_taken)
	                   ? jump_target
	                   : (instr_buffer_full | (~i_imem_ready))
	                       ? i_pc
	                       : (i_pc + 4);
endmodule
