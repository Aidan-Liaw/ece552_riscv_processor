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


module write_data_aligner(
  input wire [1:0] addr_align,
  input wire dmem_write_en,
  input wire [2:0]  func3,
  input wire [31:0] unaligned_data,

  output reg [3:0] dmem_mask,
  output reg [31:0] dmem_wdata
);
	
	wire [3:0] sb_mask;
	wire [3:0] sh_mask;
	
	left_shifter #(4, 2) sb_sll (4'b0001, addr_align, sb_mask);
	left_shifter #(4, 2) sh_sll (4'b0011, {addr_align[1], 1'b0}, sh_mask);

    //added
    wire [31:0] sb_wshifted;
    wire [31:0] sh_wshifted;

    left_shifter #(32, 5) sb2_sll ({24'b0, unaligned_data[7:0]}, {addr_align, 3'b000}, sb_wshifted);
    left_shifter #(32, 5) sh2_sll ({16'b0, unaligned_data[15:0]}, {addr_align[1], 4'b0000}, sh_wshifted);

	// write data alignment 
	always @(*) begin
		dmem_mask = 4'b0000;
		dmem_wdata = 32'b0;

    //just do write shift 
    
    // Why is the data being replicated?
    // FYI data writes to D-Mem are appropriately masked off
    // This means that we do not need to mask the data ourselves
    // Ergo, I am confused as to why this is here.
    // Check the tb.v file by the TAs' for more information
    
    // I am more concerned with whether the data must be shifted 
    // for byte and half-word accesses
    // By contrast, data reads are not masked off in the D-Mem
    // which is to say that all reads to D-Mem are of word length
    // which means that correct alignment is of our concern.
		case (dmem_write_en)
		  1'b1: begin
        case(func3)
          //sb
          3'b000: begin
            dmem_mask = sb_mask;
            //dmem_wdata = {4{unaligned_data[7:0]}};
            //if already aligned properly just pass through
            dmem_wdata = (addr_align == 2'b00) ? unaligned_data : sb_wshifted;
          end
  
          // sh
          3'b001: begin
            dmem_mask = sh_mask;
            //dmem_wdata = {2{unaligned_data[15:0]}};
            dmem_wdata = (addr_align[1] == 1'b0) ? unaligned_data : sh_wshifted;
          end
  
          // sw 
          3'b010: begin
            dmem_mask = 4'b1111;
            dmem_wdata = unaligned_data;
          end
          
          default: begin
            dmem_mask = 4'b0000;
            dmem_wdata = 32'd0;
          end
        endcase
			end
			
			default: begin
        dmem_mask = 4'b0000;
		    dmem_wdata = 32'b0;
			end
		endcase
	end 
  
endmodule
