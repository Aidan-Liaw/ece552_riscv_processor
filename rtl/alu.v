/* operations to support:
  add = 0000
  sub = 1000
  sll = 0001
  slt = 0010
  sltu = 0011
  xor = 0100
  srl = 0101
  sra = 1101
  or = 0110
  and = 0111
*/

`timescale 1ns / 1ps

`default_nettype wire

module alu (
  input wire [31:0] op1,
  input wire [31:0] op2,
  input wire [5:0] opsel,
  output wire [31:0] result
);

  wire is_arith = opsel[5];
  wire is_sub = opsel[4];
  wire is_unsigned = opsel[3];
  wire [2:0] alu_op = opsel[2:0];
  
  wire [31:0] ls_result;
  wire [31:0] rs_result;
  
  reg [31:0] result_reg;
  
  
  assign result = result_reg;
  
  left_shifter ls (op1, op2[4:0], ls_result);
  right_shifter rs (is_arith, op1, op2[4:0], rs_result);

  always @(*) begin
    case (alu_op)
      // add/sub
      3'b000:
        result_reg = is_sub == 1'b1 ? op1 - op2 : op1 + op2;

      // and
      3'b111:
        result_reg = op1 & op2;

      // or
      3'b110:
        result_reg = op1 | op2;

      // xor
      3'b100:
        result_reg = op1 ^ op2;

      // sll
      3'b001:
        result_reg = ls_result;

      // srl/sra
      3'b101:
        // Don't worry, the module checks and performs the appropriate right shift
        result_reg = rs_result;

      // slt
      3'b010:
        // MSBit same means same sign, so check for magnitude
        // Otherwise, MSBit of op1 will eliminate the remaining two options:
        // op1, op2 = 1, 0 means op1 is smaller
        // op1, op2 = 0, 1 means op1 is larger
        //op2[31] was used instead of op2[30] so magnitude was not properly compared
        result_reg = op1[31] == op2[31] ? {31'd0, op1[30:0] < op2[30:0]} : {31'd0, op1[31] == 1'b1};

      //sltu
      3'b011:
        result_reg = (op1 < op2) ? 32'b1 : 32'b0;

      default:
        result_reg = 32'b0;
    endcase
  end

endmodule
