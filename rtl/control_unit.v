`timescale 1ns / 1ps

`default_nettype wire

module control_unit (
  input wire       i_rst,
  input wire [6:0] opcode,
  input wire [2:0] funct3,
  input wire [6:0] funct7,
  input wire [4:0] rs2,
  
  input wire       keep_halting,
  
  // IF Signals
  output reg       branch,             // 1 = branch instruction. For branches only.
  output reg       jump,               // 1 = jal or jalr. For jal and jalr only.
  
  // EX Signals
  output reg [5:0] imm_format,          // Determines immediate based on instruction type.
  output reg       pc_add,              // 1 = PC, 0 = read register 1. For auipc only.
  output reg       alu_src,             // 0 = reg, 1 = imm. For i-type instructions only.
  output reg [4:0] alu_opsel,           // Sets the ALU operation.
  
  // MEM Signals
  output reg       mem_read_en,          // 1 = read from D-Mem. For loads only.
  output reg       mem_write_en,         // 1 = write to D-Mem. For stores only.
  // funct3[2:0] passthrough seen in schematic

  // WB Signals
  output reg       reg_write_en,         // 1 = write to rd. Only stores and branches don't use this.
  output reg [1:0] write_reg_sel,   // Determines what is written to rd. Only stores and branches don't use this.
  
  // Flush Signals
  output reg       if_flush,
  output reg       id_flush,
  output reg       ex_flush,
  output reg       mem_flush,

  // Global Signals
  output reg       halt_generate,               // 1 = EBREAK, stop processor. For ebreak only.
  output reg       trap
);

  wire [2:0] alu_op = (opcode == 7'b011_0011) | (opcode == 7'b001_0011) 
                    ? funct3 
                    : 3'b000;
                    
  wire       is_reg_arith = (opcode == 7'b011_0011);
  
  reg  is_arith;
  reg  is_sub;
    
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
    halt_generate = 1'b0;
    alu_src = 1'b0;
    alu_opsel = 5'd0;
    
    if_flush = 1'b0;
    id_flush = 1'b0;
    ex_flush = 1'b0;
    mem_flush = 1'b0;
    
    trap = 1'b0;
    
    casez ({i_rst, keep_halting})
      // Bad. 1'bx is not synthesizeable, and random.
      // However, I cannot force the register
      2'b1?: begin
        reg_write_en = 1'b0;
        imm_format = 6'b0;
        pc_add = 1'b0;
        branch = 1'b0;
        jump = 1'b0;
        mem_read_en = 1'b0;
        mem_write_en = 1'b0;
        //alu = 00, dmem = 11, imm = 10, pc + 4 = 01
        write_reg_sel = 2'b00;
        halt_generate = 1'b0;
        alu_src = 1'b0;
        alu_opsel = 5'd0;
        
        // Questionable...
        if_flush = 1'b0;
        id_flush = 1'b0;
        ex_flush = 1'b0;
        mem_flush = 1'b0;
        
        trap = 1'b0;
      end
      2'b00: begin
//      1'b0, 1'bx: begin
        case (opcode)
          // r-type arithmetic
          7'b011_0011: begin
            reg_write_en = 1'b1;
            imm_format = 6'b000001; 
            write_reg_sel = 2'b00; 

            alu_opsel = (funct3 == 3'b000 && funct7[5] == 1'b1) ? {1'b0, 1'b1, funct3} :
                        (funct3 == 3'b101 && funct7[5] == 1'b1) ? {1'b1, 1'b0, funct3} :
                        {1'b0, 1'b0, funct3};
          end
    
          // i-type arithmetic
          7'b001_0011: begin
            reg_write_en = 1'b1;
            alu_src = 1'b1;
            imm_format = 6'b000010;
            write_reg_sel = 2'b00;

            alu_opsel = (funct3 == 3'b101 && funct7[5] == 1'b1) ? {1'b1, 1'b0, funct3} : 
                        {1'b0, 1'b0, funct3};
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
          end
    
          // load instruction 
          7'b000_0011: begin
            imm_format = 6'b000010;
            reg_write_en = 1'b1;
            mem_read_en = 1'b1;
            alu_src = 1'b1;
            write_reg_sel = 2'b11;
          end
    
          // store instruction
          7'b010_0011: begin
            imm_format = 6'b000100;
            mem_write_en = 1'b1;
            alu_src = 1'b1;
          end
    
          // branch
          7'b110_0011: begin
            imm_format = 6'b001000;
            branch = 1'b1;
          end
    
          // jal
          7'b110_1111: begin
            reg_write_en = 1'b1;
            imm_format = 6'b100000;
            jump = 1'b1;
            write_reg_sel = 2'b01;
            if_flush = 1'b1;
          end
    
          // jalr
          7'b110_0111: begin
            reg_write_en = 1'b1;
            imm_format = 6'b000010;
            jump = 1'b1;
            write_reg_sel = 2'b01;
            alu_src = 1'b1;
            if_flush = 1'b1;
          end
    
          // EBREAK
          // NOT the proper EBREAK instruction is used (compared the RV32I standard)
          // If you check against RV32I, you will quickly see that 
          // imm[11:0] must be checked to be 11'b000000000001
          // which differs from the WISC-F25 standard that sets this imm[11:0] to all 0's
          7'b111_0011: begin
            halt_generate = 1'b1;
            if_flush = 1'b1;
          end
          
          default: begin
            halt_generate = 1'b1; // You should probably trap as well.
            trap = 1'b0;
            if_flush = 1'b1;
            id_flush = 1'b1;
            ex_flush = 1'b1;
            mem_flush = 1'b1;
          end
        endcase
      end
      
      default: begin
        case ({funct7, rs2, opcode})
          // REF: https://docs.riscv.org/reference/isa/priv/priv-insns.html
          // Use MRET to exit the EBREAK
          19'b0011000_00010_1110011 : begin
            halt_generate = 1'b0;
            if_flush = 1'b0;
          end
          default : begin
            halt_generate = 1'b1;
            if_flush = 1'b1;
          end  
        endcase
      end
    endcase      
  end
  
  // always @(*) begin
  //   is_sub = 1'b0;
  //   is_arith = 1'b0;

  //   case (alu_op)
  //     //addition/subtraction if `is_sub` asserted
  //     3'b000: is_sub = funct7[5] & is_reg_arith;

  //     //shift right logical/arithmetic if `is_arith` asserted
  //     3'b101: is_arith = funct7[5];
      
  //     default: begin
  //       is_sub = 1'b0;
  //       is_arith = 1'b0;
  //     end
  //   endcase
    
  //   alu_opsel = {is_arith, is_sub, alu_op};
  // end

endmodule 
