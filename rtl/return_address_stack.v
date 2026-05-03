`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02.05.2026 02:46:02
// Design Name: 
// Module Name: return_address_stack
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


module return_address_stack (
  input  wire                          i_clk,
  input  wire                          i_rst,
  input  wire                          i_is_push,
  input  wire                          i_is_pop,
 
  input  wire                          i_restore_state,
  
  input  wire [(32 << 5) - 1 : 0] i_restore_stack,
  input  wire [$clog2(32): 0]     i_restore_ptr,
  input  wire                          i_restore_is_empty,
  
  input  wire [31:0]                   pc,
  output wire                          is_return,
  output wire [31:0]                   return_addr,
  
  output wire [(32 << 5) - 1 : 0] o_current_stack,
  output wire [$clog2(32): 0]     o_current_ptr,
  output wire                          o_current_is_empty
);

  reg [(32 << 5) - 1 : 0] stack;
  reg [$clog2(32): 0]     ptr = 'd0;
  reg                          is_empty = 1'b1;
  
  assign return_addr = is_empty ? 32'd0 : stack[((ptr - 1) << 5) +: 32];
  assign is_return = ~is_empty;
  
  assign o_current_stack = stack;
  assign o_current_ptr = ptr;
  assign o_current_is_empty = is_empty;
    
  always @(posedge i_clk) begin
    casez ({i_rst, i_restore_state, i_is_pop & i_is_push, i_is_push, i_is_pop})
      5'b1????: begin
        stack <= 'd0;
        ptr <= 'd0;
        is_empty <= 1'b1;
      end
      5'b01000: begin
        stack <= i_restore_stack;
        ptr <= i_restore_ptr;
        is_empty <= i_restore_is_empty;
      end
      5'b011??: begin
        stack <= i_restore_stack;
        stack[((i_restore_is_empty ? 0 : i_restore_ptr - 1) << 5) +: 32] <= pc + 32'd4;
        ptr <= i_restore_is_empty ? 1 : i_restore_ptr;
        is_empty <= 1'b0;
      end
      5'b01010: begin
        stack <= i_restore_stack;        
        stack[((i_restore_ptr == 32 ? 32 - 1 : i_restore_ptr) << 5) +: 32] <= i_restore_ptr != 32 ? pc + 32'd4: i_restore_stack[((32 - 1) << 5) +: 32];
        ptr <= i_restore_ptr != 32 ? i_restore_ptr + 1 : i_restore_ptr;
        is_empty <= 1'b0;
      end
      5'b01001: begin
        stack <= i_restore_stack;
        ptr <= i_restore_is_empty ? 0 : i_restore_ptr - 1;
        is_empty <= i_restore_is_empty | (i_restore_ptr == 'd1);
      end
      5'b001??: begin
        stack[((is_empty ? 0 : ptr - 1) << 5) +: 32] <= pc + 32'd4;
        ptr <= is_empty ? 1 : ptr;
        is_empty <= 1'b0;
      end
      5'b00010: begin
        stack[((ptr == 32 ? 32 - 1 : ptr) << 5) +: 32] <= ptr != 32 ? pc + 32'd4: stack[((32 - 1) << 5) +: 32];
        ptr <= ptr != 32 ? ptr + 1 : ptr;
        is_empty <= 1'b0;
      end
      5'b00001: begin
        ptr <= is_empty ? 0 : ptr - 1;
        is_empty <= is_empty | (ptr == 'd1);
      end
      default: begin
      end
    endcase
  end
endmodule
