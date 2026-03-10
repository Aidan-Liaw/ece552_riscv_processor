`timescale 1ns / 1ps

`default_nettype wire

module fetch #(
  parameter RESET_ADDR = 32'h00000000
) (
  input  wire        i_clk,
  input  wire        i_rst,
  input  wire        halt,
  
  input  wire [31:0] target_pc,
  input  wire        is_jump_or_branch,
  input  wire        pc_write_en,
  
  output wire [31:0] pc,
  output wire [31:0] pc_plus_4
);

  reg [31:0] pc_reg; // The PC register from the schematic
  
  assign pc = pc_reg;
  assign pc_plus_4 = pc_reg + 32'd4; // The output wire of the adder for PC + 4
  
  always @(posedge i_clk) begin
		if (i_rst) begin
			pc_reg <= RESET_ADDR;
		end else if ((~halt) & pc_write_en & is_jump_or_branch) begin
			pc_reg <= target_pc;
		end else if ((~halt) & pc_write_en & (~is_jump_or_branch)) begin
			pc_reg <= pc_plus_4;
    end else begin
      pc_reg <= pc_reg;
    end 
	end
	
endmodule
