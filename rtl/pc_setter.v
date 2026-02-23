`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 22.02.2026 21:53:00
// Design Name: 
// Module Name: pc_setter
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


module pc_setter(
  input  wire        branch,
  input  wire [3:0]  func3,
  input  wire [31:0] rs1_data,
  input  wire [31:0] rs2_data,
  
  output reg        branch_taken
);
      
	always @(*) begin
		if (branch) begin
			case(func3)
				3'b000: 
					branch_taken = (rs1_data == rs2_data);  // beq
				3'b001: 
					branch_taken = (rs1_data != rs2_data);  // bne
				3'b100: 
					branch_taken = rs1_data[31] == rs2_data[31] ? rs1_data[30:0] < rs2_data[31:0] : rs1_data[31] == 1'b1;  // blt
				3'b101: 
					branch_taken = rs1_data[31] == rs2_data[31] ? rs1_data[30:0] >= rs2_data[31:0] : rs1_data[31] == 1'b0;  // bge
				3'b110: 
					branch_taken = (rs1_data < rs2_data);  // bltu
				3'b111: 
					branch_taken = (rs1_data >= rs2_data);  // bgeu
				default: 
					branch_taken = 1'b0;
			endcase
		end else begin
			branch_taken = 1'b0;
		end
	end
	
endmodule
