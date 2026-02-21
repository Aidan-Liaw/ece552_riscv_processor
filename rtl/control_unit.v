`default_nettype wire

module control_unit (
  input wire [6:0] opcode,

  // mux controls
  output reg RegSignPropagation,
  output reg RegReadSize,
  output reg immFormat [5:0],
  output reg pcAdd,
  output reg memMask[3:0],
  output reg registerWriteSel,
  output reg aluSrc,      // 0 = reg, 1 = imm
  output reg emtoReg,   // 0 = alu result, 1 = mem data
  output reg regWrite,    // 1 = write too rd
  output reg memRead,     // 1 = read from mem
  output reg memWrite,    // 1 = write to mem
  output reg branch,       // 1 = branch instruction 
  output reg jump,         // 1 = jal or jalr
  output reg halt,         // 1 = EBREAK, stop processor
  output reg retire,
  output reg [1:0] aluOP[3:0]
);

  always @(*) begin
    alu_src = 1'b0;
    mem_to_reg = 1'b0;
    reg_write = 1'b0;
    mem_read = 1'b0;
    mem_write = 1'b0;
    branch = 1'b0;
    jump = 1'b0;
    stop = 1'b0;
    alu_op_type = 2'b00;

    case (opcode)
      // r-type arithmetic
      7'b0110011: begin
        reg_write = 1'b1;
        alu_op_type = 2'b10;
      end

      // i-type arithmetic
      7'b0010011: begin
        alu_src = 1'b1;
        reg_write = 1'b1;
        alu_op_type = 2'b11;
      end

      // load instruction 
      7'b0000011: begin
        alu_src = 1'b1;
        mem_to_reg = 1'b1;
        reg_write = 1'b1;
        mem_read = 1'b1;
        alu_op_type = 2'b00;
      end

      // store instruction
      7'b0100011: begin
        alu_src = 1'b1;
        mem_write = 1'b1;
        alu_op_type = 2'b00;
      end

      // branch
      7'b1100011: begin
        branch = 1'b1;
        alu_op_type = 2'b01;
      end

      // jal
      7'b1101111: begin
        jump = 1'b1;
        reg_write = 1'b1;
      end

      // jalr
      7'b1100111: begin
        jump = 1'b1;
        reg_write 1'b1;
        alu_src = 1'b1;
        alu_op_type 2'b00;
      end

      // lui
      7'b0110111: begin
        reg_write = 1'b1;
        alu_src = 1'b1;
      end

      // auipc
      7'b0010111:
        reg_write = 1'b1;
      end

      // EBREAK
      7'b1110011: begin
        stop = 1'b1;
      end
    endcase
  end

endmodule 
