`timescale 1ns / 1ps

`default_nettype wire

module alu_control (
  input wire [2:0] alu_op,
  input wire [2:0] funct3,  
  input wire [6:0] funct7, 
  input wire is_immediate,
  
  output wire [5:0] opsel
);

  reg is_arith;
  reg is_sub;
  reg is_unsigned;

  always @(*) begin
    is_sub = 1'b0;
    is_arith = 1'b0;
    is_unsigned = 1'b0;

    case (alu_op)
      //addition/subtraction if `is_sub` asserted
      3'b000: is_sub = funct7[5] & ~is_immediate;

      //set less than/unsigned if `is_unsigned` asserted
      // This is not necessary AFAIK. 
      // It does not not use funct7 to distinguish between unsigned and signed.
      3'b011: is_unsigned = ((funct3 == 3'b011) & ~is_immediate) ? 1'b1: 1'b0;

      //shift right logical/arithmetic if `is_arith` asserted
      3'b101: is_arith = funct7[5] & (~is_immediate | (is_immediate & (alu_op == 3'b101)) );
      
      default: begin
        is_sub = 1'b0;
        is_arith = 1'b0;
        is_unsigned = 1'b0;
      end

    endcase
  end
  
  assign opsel[5] = is_arith;
  assign opsel[4] = is_sub;
  assign opsel[3] = is_unsigned;
  assign opsel[2:0] = alu_op;

endmodule 
