`timescale 1ns / 1ps

`default_nettype wire

module control_unit (
  input wire [6:0] opcode,
  input wire [2:0] funct3,

  // mux controls
  output reg       reg_write_en,         // 1 = write to rd. Only stores and branches don't use this.
  output reg [5:0] imm_format,          // Determines immediate based on instruction type.
  output reg       pc_add,              // 1 = PC, 0 = read register 1. For auipc only.
  output reg       branch,             // 1 = branch instruction. For branches only.
  output reg       jump,               // 1 = jal. For jal only.
  output reg       mem_read_en,          // 1 = read from D-Mem. For loads only.
  output reg       mem_write_en,         // 1 = write to D-Mem. For stores only.
  output reg [1:0] write_reg_sel,   // Determines what is written to rd. Only stores and branches don't use this.
  output reg       halt,               // 1 = EBREAK, stop processor. For ebreak only.
  output reg       trap,
  output reg       alu_src,             // 0 = reg, 1 = imm. For i-type instructions only.
  output reg [2:0] alu_op               // Sets the ALU operation.
);

  always @(*) begin
    reg_write_en = 1'b0;
    imm_format = 6'b0;
    pc_add = 1'b0;
    branch = 1'b0;
    jump = 1'b0;
    mem_read_en = 1'b0;
    mem_write_en = 1'b0;
    //alu = 00, dmem = 11, imm = 10, pc + 4 = 01
    write_reg_sel = 2'b00;
    halt = 1'b0;
    alu_src = 1'b0;
    alu_op = 3'b000;

    case (opcode)
      // r-type arithmetic
      7'b011_0011: begin
        reg_write_en = 1'b1;
        imm_format = 6'b000001; 
        write_reg_sel = 2'b00; 
        //modified to still distinguish between slt and sltu
        alu_op = funct3;
      end

      // i-type arithmetic
      7'b001_0011: begin
        reg_write_en = 1'b1;
        alu_src = 1'b1;
        imm_format = 6'b000010;
        write_reg_sel = 2'b00;
        alu_op = funct3;
      end
      
      // lui
      7'b011_0111: begin
        reg_write_en = 1'b1;
        imm_format = 6'b010000;
        write_reg_sel = 2'b10;
      end

      // auipc
      7'b001_0111: begin
        reg_write_en = 1'b1;
        imm_format = 6'b010000; 
        pc_add = 1'b1;
        write_reg_sel = 2'b00; 
        alu_src = 1'b1;
        alu_op = 3'b000;
      end

      // load instruction 
      7'b000_0011: begin
        imm_format = 6'b000010;
        reg_write_en = 1'b1;
        mem_read_en = 1'b1;
        alu_src = 1'b1;
        alu_op = 3'b000;
        write_reg_sel = 2'b11;
      end

      // store instruction
      7'b010_0011: begin
        imm_format = 6'b000100;
        mem_write_en = 1'b1;
        alu_src = 1'b1;
        alu_op = 3'b000; // Is this needed? We're not writing to the register file
      end

      // branch
      7'b110_0011: begin
        imm_format = 6'b001000;
        branch = 1'b1;
        alu_op = 3'b000;
      end

      // jal
      // I AM HEAVILY CONCERNED ABOUT THIS
      // If we expect this to be added to PC via the same adder that is used for the branch instruction,
      // This will fail.
      // This is because it has to passthrough the branch mux, which it cannot do.
      // I have changed the schematic to fix this. 
      7'b110_1111: begin
        reg_write_en = 1'b1;
        imm_format = 6'b100000;
        jump = 1'b1;
        write_reg_sel = 2'b01; 
      end

      // jalr
      7'b110_0111: begin
        reg_write_en = 1'b1;
        imm_format = 6'b000010;
        jump = 1'b1;
        write_reg_sel = 2'b01;
        alu_src = 1'b1;
        alu_op = 3'b000;
      end

      // EBREAK
      7'b111_0011: begin
        halt = 1'b1;
      end
      
      default: begin
        halt = 1'b1; // You should probably trap as well.
        trap = 1'b0;
      end
    endcase
  end

endmodule 
