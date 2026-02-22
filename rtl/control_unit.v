`default_nettype wire

module control_unit (
  input wire [6:0] opcode,
  input wire [2:0] func3,

  // mux controls
  output reg RegSignPropagation,
  output reg [1:0] RegReadSize,
  output reg [5:0] immFormat,
  output reg pcAdd,
  output reg [3:0] memMask,
  output reg [1:0] registerWriteSel,
  output reg aluSrc,      // 0 = reg, 1 = imm
  output reg regWrite,    // 1 = write to rd
  output reg memRead,     // 1 = read from mem
  output reg memWrite,    // 1 = write to mem
  output reg branch,       // 1 = branch instruction 
  output reg jump,         // 1 = jal or jalr
  output reg halt,         // 1 = EBREAK, stop processor
  output reg retire,
  output reg [2:0] aluOP
);

  always @(*) begin
    RegSignPropagation = 1'b0;
    //default size is a word
    RegReadSize = 2'b10;
    immFormat = 6'b0;
    pcAdd = 1'b0;
    memMask = 4'b0000;
    //alu = 00, dmem = 01, imm = 10, pc = 11
    registerWriteSel = 2'b00;
    aluSrc = 1'b0;
    regWrite = 1'b0;
    memRead = 1'b0;
    memWrite = 1'b0;
    branch = 1'b0;
    jump = 1'b0;
    halt = 1'b0;
    retire = 1'b1;
    aluOP = 3'b000;

    case (opcode)
      // r-type arithmetic
      7'b0110011: begin
        regWrite = 1'b1;
        aluSrc = 1'b0;
        immFormat = 6'b000001; 
        registerWriteSel = 2'b00; 
        case (func3)
            3'b000: aluOP = 3'b000; 
            3'b001: aluOP = 3'b001; 
            3'b010: aluOP = 3'b011;
            3'b011: aluOP = 3'b011; 
            3'b100: aluOP = 3'b100; 
            3'b101: aluOP = 3'b101; 
            3'b110: aluOP = 3'b110; 
            3'b111: aluOP = 3'b111; 
        endcase
      end

      // i-type arithmetic
      7'b0010011: begin
        regWrite = 1'b1;
        aluSrc = 1'b1;
        immFormat = 6'b000010;
        registerWriteSel = 2'b00;
        case (func3)
            3'b000: aluOP = 3'b000; 
            3'b001: aluOP = 3'b001; 
            3'b010: aluOP = 3'b011;
            3'b011: aluOP = 3'b011; 
            3'b100: aluOP = 3'b100; 
            3'b101: aluOP = 3'b101; 
            3'b110: aluOP = 3'b110; 
            3'b111: aluOP = 3'b111; 
        endcase
      end

      // load instruction 
      7'b0000011: begin
        regWrite = 1'b1;
        aluSrc = 1'b1;
        memRead = 1'b1;
        aluOP = 3'b000;
        immFormat = 6'b000010;
        registerWriteSel = 2'b01;
        case (func3)
            //byte
            3'b000: begin
                RegReadSize = 2'b00; 
                RegSignPropagation = 1'b1;
            end
            //half
            3'b001: begin
                RegReadSize = 2'b01; 
                RegSignPropagation = 1'b1;
            end
            //word
            3'b010: begin
                RegReadSize = 2'b10; 
                RegSignPropagation = 1'b1;
            end
            //byte unsigned
            3'b100: begin
                RegReadSize = 2'b00; 
                RegSignPropagation = 1'b0;
            end
            //half unsigned
            3'b101: begin
                RegReadSize = 2'b01; 
                RegSignPropagation = 1'b0;
            end
        endcase
      end

      // store instruction
      7'b0100011: begin
        aluSrc = 1'b1;
        memWrite = 1'b1;
        aluOP = 3'b000;
        immFormat = 6'b000100;
        case (func3)
            3'b000: memMask = 4'b0001;
            3'b001: memMask = 4'b0011;
            3'b010: memMask = 4'b1111;
        endcase
      end

      // branch
      7'b1100011: begin
        branch = 1'b1;
        aluOP = 3'b000;
        immFormat = 6'b001000;
      end

      // jal
      7'b1101111: begin
        jump = 1'b1;
        regWrite = 1'b1;
        immFormat = 6'b100000;
        registerWriteSel = 2'b11; 
      end

      // jalr
      7'b1100111: begin
        jump = 1'b1;
        regWrite = 1'b1;
        aluSrc = 1'b1;
        aluOP = 3'b000;
        immFormat = 6'b000010;
        registerWriteSel = 2'b11;
      end

      // lui
      7'b0110111: begin
        regWrite = 1'b1;
        aluSrc = 1'b1;
        immFormat = 6'b010000;
        registerWriteSel = 2'b10;
      end

      // auipc
      7'b0010111: begin
        regWrite = 1'b1;
        aluSrc = 1'b1;
        pcAdd = 1'b1;
        immFormat = 6'b010000; 
        registerWriteSel = 2'b00; 
        aluOP = 3'b000;
      end

      // EBREAK
      7'b1110011: begin
        halt = 1'b1;
      end
    endcase
  end

endmodule 
