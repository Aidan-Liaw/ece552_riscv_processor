`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 23.02.2026 00:54:52
// Design Name: 
// Module Name: data_aligner
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


module read_data_aligner(
  input wire  [1:0]  addr_align,
  input wire         dmem_read_en,
  input wire  [2:0]  func3,
  input wire  [31:0] i_dmem_rdata,
  
  output wire [31:0] mem_read_data,
  output reg  [3:0]  dmem_mask
);
	
	reg [31:0] mem_data;
  wire [31:0] shifted_rdata;

	wire [3:0]  lb_lbu_mask;
	wire [3:0]  lh_lhu_mask;
	
	
	assign mem_read_data = mem_data;
	
	left_shifter #(4, 2) lb_lbu_sll (4'b0001, addr_align, lb_lbu_mask);
  left_shifter #(4, 2) lh_lhu_sll (4'b0011, {addr_align[1], 1'b0}, lh_lhu_mask);	


  // read data alignment 
	always @(*) begin
		dmem_mask = 4'b0000;

		case (dmem_read_en)
		  1'b1: begin
        case (func3)
          // lb and lbu
          3'b000, 3'b100:
            dmem_mask = lb_lbu_mask;
          // lh and lhu
          3'b001, 3'b101: 
            dmem_mask = lh_lhu_mask;
          // lw
          3'b010:
            dmem_mask = 4'b1111;  
            
           default:
            dmem_mask = 4'b0000;
        endcase
      end
      
      default: begin
        dmem_mask = 4'b0000;
      end
		endcase
	end 
	
	right_shifter #(32, 5) rdata_srl (1'b0, i_dmem_rdata, {addr_align, 3'b000}, shifted_rdata);

	always @(*) begin
		case (func3)
			// lb
			3'b000:
				mem_data = {{24{shifted_rdata[7]}}, shifted_rdata[7:0]};
			// lbu
			3'b100:
				mem_data = {24'b0, shifted_rdata[7:0]};
			// lh
			3'b001: 
				mem_data = {{16{shifted_rdata[15]}}, shifted_rdata[15:0]};
			// lhu
			3'b101:
				mem_data = {16'b0, shifted_rdata[15:0]};
			// lw
			default:
				mem_data = shifted_rdata;
		endcase
	end
  
endmodule