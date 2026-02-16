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
  input wire [31:0] op1,
  input wire [31:0] op2,
  input wire [3:0] alu_op,
  output reg [31:0] result,
  outpute wire zero
);

  assign zero = (result == 32'b0);

  always @(*) begin
    case (alu_op)
      // add
      4'b0000:
        result = op1 + op2;

      // sub
      4'b1000:
        result = op1 - op2;

      // and
      4'b0111:
        result = op1 & op2;

      // or
      4'b0110:
        result = op1 | op2;

      // xor
      4'b0100:
        result = op1 ^ op2;

      // sll
      4'b0001:
        result = op1 << op2[4:0];

      // srl
      4'b0101:
        result = op1 >> op2[4:0];

      // sra
      4'b1101:

      // slt
      4'b0010:

      //sltu
      4'b0011:

      default:
        result = 32'b0;
    endcase
  end

endmodule
