`default_nettype wire

module alu_control (
  input wire [1:0] alu_op_type,
  input wire [2:0] func3,  // instruction[14:12]
  input wire bit30,  // instruction[30]
  output reg [3:0] alu_cmd
);

  localparam TYPE_MEM = 2'b00;
  localparam TYPE_BR = 2'b01;
  localparam TYPE_R = 2'b10;
  localparam TYPE_I = 2'b11;

  always @(*) begin
    case (alu_op_type)
      TYPE_MEM:
        alu_cmd = 4'b0000;

      TYPE_BR:
        alu_cmd = 4'b1000;

      TYPE_R:
        alu_cmd = {bit30, func3};

      TYPE_I: begin
        if (func3 == 3'b101 || func3 == 3'b001) begin
          alu_cmd = {bit30, func3};
        end else begin 
          alu_cmd = {1'b0, func3};
        end
      end

      default: 
        alu_cmd 4'b0000;
    endcase
  end

endmodule 
