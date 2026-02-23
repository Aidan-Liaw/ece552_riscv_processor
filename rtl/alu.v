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

`default_nettype wire

module alu (
  input wire [31:0] i_op1,
  input wire [31:0] i_op2,
  input wire [5:0] i_opsel,
  output wire [31:0] result,
  output wire zero
);

  wire is_arith = i_opsel[5];
  wire is_sub = i_opsel[4];
  wire is_unsigned = i_opsel[3];
  wire [2:0] alu_op = i_opsel[2:0];
  
  wire [31:0] ls_result;
  wire [31:0] rs_result;
  
  reg result_reg;
  
  assign zero = (result == 32'b0);
  
  assign result = result_reg;
  
  left_shifter ls (i_op1, i_op2[4:0], ls_result);
  right_shifter rs (is_arith, i_op1, i_op2[4:0], rs_result);

  always @(*) begin
    case (alu_op)
      // add/sub
      3'b000:
        result_reg = is_sub == 1'b1 ? i_op1 - i_op2 : i_op1 + i_op2;

      // and
      3'b111:
        result_reg = i_op1 & i_op2;

      // or
      3'b110:
        result_reg = i_op1 | i_op2;

      // xor
      3'b100:
        result_reg = i_op1 ^ i_op2;

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
        // Otherwise, MSBit of i_op1 will eliminate the remaining two options:
        // i_op1, i_op2 = 1, 0 means i_op1 is smaller
        // i_op1, i_op2 = 0, 1 means i_op1 is larger
        result_reg = i_op1[31] == i_op2[31] ? i_op1[30:0] < i_op2[31:0] : i_op1[31] == 1'b1;

      //sltu
      3'b011:
        result_reg = (i_op1 < i_op2) ? 32'b1 : 32'b0;

      default:
        result_reg = 32'b0;
    endcase
  end

endmodule
