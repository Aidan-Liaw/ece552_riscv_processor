`timescale 1ns / 1ps

`default_nettype wire

module control_unit (
  input wire [6:0] opcode,
  input wire [2:0] funct3,

  // mux controls
  output reg       RegSignPropagation, // 1 for sign propagation for partial word loads. For loads only.
  output reg [1:0] RegReadSize,        // Determines what the load size is. For loads only.
  output reg       RegWriteEn,         // 1 = write to rd. Only stores and branches don't use this.
  output reg [5:0] ImmFormat,          // Determines immediate based on instruction type.
  output reg       PCAdd,              // 1 = PC, 0 = read register 1. For auipc only.
  output reg       Branch,             // 1 = branch instruction. For branches only.
  output reg       Jump,               // 1 = jal. For jal only.
  output reg       JalrJump,           // 1 = jalr. For jalr only.
  output reg       MemReadEn,          // 1 = read from D-Mem. For loads only.
  output reg       MemWriteEn,         // 1 = write to D-Mem. For stores only.
  output reg [1:0] RegisterWriteSel,   // Determines what is written to rd. Only stores and branches don't use this.
  output reg       Halt,               // 1 = EBREAK, stop processor. For ebreak only.
  output reg       Trap,
  output reg       Retire,             // Unused. Currently constant 1.
  output reg       ALUSrc,             // 0 = reg, 1 = imm. For i-type instructions only.
  output reg [2:0] ALUOp               // Sets the ALU operation.
);

  always @(*) begin
    RegSignPropagation = 1'b0;
    //default size is a word
    RegReadSize = 2'b10;
    RegWriteEn = 1'b0;
    ImmFormat = 6'b0;
    PCAdd = 1'b0;
    Branch = 1'b0;
    Jump = 1'b0;
    JalrJump = 1'b0;
    MemReadEn = 1'b0;
    MemWriteEn = 1'b0;
    //alu = 00, dmem = 11, imm = 10, pc + 4 = 01
    RegisterWriteSel = 2'b00;
    Halt = 1'b0;
    Retire = 1'b1;
    ALUSrc = 1'b0;
    ALUOp = 3'b000;

    case (opcode)
      // r-type arithmetic
      7'b011_0011: begin
        RegWriteEn = 1'b1;
        ImmFormat = 6'b000001; 
        RegisterWriteSel = 2'b00; 
        ALUOp = funct3 == 3'b010 ? 3'b011 : funct3;
      end

      // i-type arithmetic
      7'b001_0011: begin
        RegWriteEn = 1'b1;
        ALUSrc = 1'b1;
        ImmFormat = 6'b000010;
        RegisterWriteSel = 2'b00;
        ALUOp = funct3 == 3'b010 ? 3'b011 : funct3;
      end
      
      // lui
      7'b011_0111: begin
        RegWriteEn = 1'b1;
        ImmFormat = 6'b010000;
        RegisterWriteSel = 2'b10;
      end

      // auipc
      7'b001_0111: begin
        RegWriteEn = 1'b1;
        ImmFormat = 6'b010000; 
        PCAdd = 1'b1;
        RegisterWriteSel = 2'b00; 
        ALUSrc = 1'b1;
        ALUOp = 3'b000;
      end

      // load instruction 
      7'b000_0011: begin
        // Check against the opcodes to verify this
        // TLDR: MSBit is the inverse of unsigned vs signed
        //       Read size is dependent on the bottom two bits
        RegSignPropagation = ~funct3[2];
        RegReadSize = funct3[1:0];
        ImmFormat = 6'b000010;
        RegWriteEn = 1'b1;
        MemReadEn = 1'b1;
        ALUSrc = 1'b1;
        ALUOp = 3'b000;
        RegisterWriteSel = 2'b11;
      end

      // store instruction
      7'b010_0011: begin
        ImmFormat = 6'b000100;
        MemWriteEn = 1'b1;
        ALUSrc = 1'b1;
        ALUOp = 3'b000; // Is this needed? We're not writing to the register file
      end

      // Branch
      7'b110_0011: begin
        ImmFormat = 6'b001000;
        Branch = 1'b1;
        ALUOp = 3'b000;
      end

      // jal
      // I AM HEAVILY CONCERNED ABOUT THIS
      // If we expect this to be added to PC via the same adder that is used for the branch instruction,
      // This will fail.
      // This is because it has to passthrough the branch mux, which it cannot do.
      // I have changed the schematic to fix this. 
      7'b110_1111: begin
        RegWriteEn = 1'b1;
        ImmFormat = 6'b100000;
        Jump = 1'b1;
        RegisterWriteSel = 2'b01; 
      end

      // jalr
      7'b110_0111: begin
        RegWriteEn = 1'b1;
        ImmFormat = 6'b000010;
        JalrJump = 1'b1;
        RegisterWriteSel = 2'b01;
        ALUSrc = 1'b1;
        ALUOp = 3'b000;
      end

      // EBREAK
      7'b111_0011: begin
        Halt = 1'b1;
      end
      
      default: begin
        Halt = 1'b1; // You should probably trap as well.
        Trap = 1'b0;
      end
    endcase
  end

endmodule 
