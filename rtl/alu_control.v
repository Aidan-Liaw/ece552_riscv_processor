`default_nettype wire

module alu_control (
  input wire [2:0] aluOP,
  input wire [2:0] func3,  
  input wire [7:0] func7, 

  output reg [2:0] alu_op,
  output reg i_sub,       
  output reg i_arith,   
  output reg i_unsigned  
);

  always @(*) begin
    alu_op = aluOP;
    i_sub = 1'b0;
    i_arith = 1'b0;
    i_unsigned = 1'b0;

    case (aluOP)
      //addition/subtraction if `i_sub` asserted
      3'b000: i_sub = func7[5];

      //set less than/unsigned if `i_unsigned` asserted
      3'b011: i_unsigned = (func3 == 3'b011) ? 1'b1: 1'b0;

      //shift right logical/arithmetic if `i_arith` asserted
      3'b101: i_arith = func7[5];

    endcase
  end

endmodule 
