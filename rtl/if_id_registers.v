`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08.03.2026 19:48:50
// Design Name: 
// Module Name: if_id_registers
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module if_id_registers #(
  parameter RESET_ADDR = 32'h00000000,
  parameter NOP_INSTRUCTION = 32'h00000013,
  // Stupid, very stupid, blame the linter
  // Do as I (Aidan) say not as I do, unless you want very generic code, 
  // 1. Go to your boss to ask for exceptions, otherwise,
  // 2. Never write your HDL like this...
  
  // YOU MUST MAKE THIS A POWER OF 2, otherwise all of the bit shifts will fail
  // and all of the offset accesses and replication operators will fail. BADLY.
  // You must manually calcuate and replace these offsets and replications if so.
  parameter IMEM_INSTR_BUFFER_INTEGER_SIZE = 8,
  parameter [$clog2(IMEM_INSTR_BUFFER_INTEGER_SIZE) + 1 : 0] IMEM_INSTR_BUFFER_SIZE = IMEM_INSTR_BUFFER_INTEGER_SIZE,
  parameter IMEM_INSTR_BUFFER_BITS = $clog2(IMEM_INSTR_BUFFER_SIZE) + 1
) (
  input  wire        i_clk,
  input  wire        halt,
  input  wire        if_flush,
  input  wire        write_en,
  
  input  wire [31:0] i_instr,
  input  wire [31:0] i_pc,
  input  wire        i_imem_valid,
  
  output wire [31:0] o_instr,
  output wire [31:0] o_pc,
  output wire        o_valid,  // 3/25 UPDATE
  output wire        o_buffer_empty,
  output wire        o_buffer_full
);
  
  reg [31:0] instr = NOP_INSTRUCTION;
  reg [(32 << $clog2(IMEM_INSTR_BUFFER_INTEGER_SIZE)) - 1:0] instr_valid = {32 << $clog2(IMEM_INSTR_BUFFER_INTEGER_SIZE){1'b0}};
  reg [(32 << $clog2(IMEM_INSTR_BUFFER_INTEGER_SIZE)) - 1:0] pc_valid = {32 << $clog2(IMEM_INSTR_BUFFER_INTEGER_SIZE){1'b0}};
  // Dumb stupid dumb way of getting -1, which is due to limits with not using SV and the stupid stupid linter
  reg [$clog2(IMEM_INSTR_BUFFER_SIZE):0] is_valid_and_halt_counter = {IMEM_INSTR_BUFFER_BITS{1'b1}};

  reg [31:0] pc = RESET_ADDR;
  reg        valid = 1'b0;  // 3/25 UPDATE: to track validity
  
  assign o_instr = instr;
  assign o_pc = pc;
  assign o_valid = valid;  // 3/25 UPDATE
  assign o_buffer_empty = is_valid_and_halt_counter == {IMEM_INSTR_BUFFER_BITS{1'b1}};
  assign o_buffer_full = is_valid_and_halt_counter == IMEM_INSTR_BUFFER_SIZE - 1;
  
  // Unfortunately, there may be a situation whereby a halt and a valid instruction may occur.
  // This is particularly problematic as the data is only available
  // on the cycle where i_imem_valid asserts
  // Which means if a halt occurs on the same cycle as a valid instruction is outputted from I-mem,
  // the instruction must be re-fetched (which hurts CPI), or temporarily stored in a buffer
  // and conditionally read based on whether a halt previously occured
  // **Should this logic not work, you should instead trigger an instruction refetch if you cannot fix it**
  // Note that when it comes to optimisation time, we should implement proper prefetch such that instructions can still be fetched
  // while waiting for D-Mem
  always @(posedge i_clk) begin
    //read from base address up to 32 bits
    instr_valid[(is_valid_and_halt_counter << 5) +: 32] <= (i_imem_valid == 1'b1) & ((is_valid_and_halt_counter + 1) != IMEM_INSTR_BUFFER_SIZE)
                                      ? i_instr
                                      : instr_valid[(is_valid_and_halt_counter << 5) +: 32];
    pc_valid[(is_valid_and_halt_counter << 5) +: 32] <= (i_imem_valid == 1'b1) & ((is_valid_and_halt_counter + 1) != IMEM_INSTR_BUFFER_SIZE)
                                              ? i_pc
                                              : pc_valid[(is_valid_and_halt_counter << 5) +: 32];
    is_valid_and_halt_counter <= (i_imem_valid == 1'b1) & ((is_valid_and_halt_counter + 1) != IMEM_INSTR_BUFFER_SIZE)
                                    ? is_valid_and_halt_counter + 1
                                    : is_valid_and_halt_counter;
  end

  always @(posedge i_clk) begin
    casez ({halt, if_flush, write_en})
      3'b1?? : begin
        instr <= NOP_INSTRUCTION;
        valid <= 1'b0;  // 3/25 UPDATE
        
        // If there is a valid instruction issued during a halt, this control signal increments
        // and decrements when write_en becomes active.
        // This is because I-Mem data is only valid on the clock cycle that which the i_imem_valid asserts
        // So if you miss the insurtcion read, you must either refetch otherwise an instruction will be missed
        is_valid_and_halt_counter <= i_imem_valid
                                      ? is_valid_and_halt_counter + 1
                                      : is_valid_and_halt_counter;
      end
      3'b01? : begin
        instr <= NOP_INSTRUCTION;
        pc <= i_pc;
        valid <= 1'b0;  // 3/25 UPDATE: flushed instruction becomes invalid
        is_valid_and_halt_counter <= {IMEM_INSTR_BUFFER_BITS{1'b1}}; // All prefetched instructions go away
      end
      3'b001 : begin
        // Fetched instructions during halts take priority
        // This is to ensure that the in-order property of instruction fetches is respected
        instr <= (is_valid_and_halt_counter != ({IMEM_INSTR_BUFFER_BITS{1'b1}}))
                    ? instr_valid[(is_valid_and_halt_counter << 5) +: 32]
                    : i_instr;
        pc <= (is_valid_and_halt_counter != ({IMEM_INSTR_BUFFER_BITS{1'b1}}))
                ? pc_valid[(is_valid_and_halt_counter << 5) +: 32]
                : i_pc;
        valid <= i_imem_valid | (is_valid_and_halt_counter != ({IMEM_INSTR_BUFFER_BITS{1'b1}}));  // 3/25 UPDATE: pass validity through
        is_valid_and_halt_counter <= (is_valid_and_halt_counter != ({IMEM_INSTR_BUFFER_BITS{1'b1}}))
                                      ? is_valid_and_halt_counter - 1
                                      : is_valid_and_halt_counter;
      end
      default : begin
        instr <= instr;
        pc <= pc;
        valid <= valid;
        is_valid_and_halt_counter <= is_valid_and_halt_counter;
      end
    endcase
	end
endmodule
