`timescale 1ns / 1ps

`default_nettype wire

module execute (
  input  wire [31:0] pc,
  input  wire [31:0] imm_val,
  
  // Register data
  input  wire [31:0] rs1_data,
  input  wire [31:0] rs2_data,
  
  // Control Unit wires
  // Execute stage control
  input  wire        pc_add, // 0 for rs1_data, 1 for PC
  input  wire        alu_src, // 0 for rs2_data, 1 for immediate
  input  wire [ 4:0] alu_opsel, // ALU Control Signal
  
  output wire [31:0] alu_result
);

	wire [31:0] alu_in_a, alu_in_b; // ALU inputs
	
		// alu muxes 
	assign alu_in_a = (pc_add) ? pc : rs1_data;
	assign alu_in_b = (alu_src) ? imm_val : rs2_data;

	alu arith_logic_unit (
		.op1(alu_in_a), .op2(alu_in_b), .opsel(alu_opsel), .result(alu_result)
	);

endmodule