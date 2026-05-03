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
  parameter IMEM_INSTR_BUFFER_BITS = $clog2(IMEM_INSTR_BUFFER_SIZE) + 1,
  parameter RAS_ENTRIES = 32
) (
  input  wire        i_clk,
  input  wire        i_rst,
  input  wire        halt,
  input  wire        if_flush,
  input  wire        write_en,
  input  wire        i_imem_ready,
  input  wire        i_imem_ren,

  input  wire [31:0] i_instr,
  input  wire [31:0] i_pc,
  input  wire        i_imem_valid,
  
  input  wire [(RAS_ENTRIES << 5) - 1 : 0] i_ras_restore_stack,
  input  wire [$clog2(RAS_ENTRIES): 0]     i_ras_restore_ptr,
  input  wire                              i_ras_restore_is_empty,
    
  input  wire        i_predict_is_taken,
  input  wire [31:0] i_predicted_pc,
  input  wire [31:0] i_predicted_target_pc,

  output wire [31:0] o_instr,
  output wire [31:0] o_pc,
  output wire        o_valid,  // 3/25 UPDATE
  output wire        o_buffer_empty,
  output wire        o_buffer_full,
  
  output wire [(RAS_ENTRIES << 5) - 1 : 0] o_ras_restore_stack,
  output wire [$clog2(RAS_ENTRIES): 0]     o_ras_restore_ptr,
  output wire                              o_ras_restore_is_empty,
  
  output wire        o_predict_is_taken,
  output wire [31:0] o_predicted_pc,
  output wire [31:0] o_predicted_target_pc
);
  
  localparam [IMEM_INSTR_BUFFER_BITS - 1:0] IMEM_BUFFER_COUNT_MAX = IMEM_INSTR_BUFFER_INTEGER_SIZE;
  localparam PTR_BITS = $clog2(IMEM_INSTR_BUFFER_INTEGER_SIZE);

  reg [31:0] instr;
  reg [31:0] pc;
  reg        valid;  // 3/25 UPDATE: to track validity
  
  reg [(RAS_ENTRIES << 5) - 1 : 0] ras_restore_stack;
  reg [$clog2(RAS_ENTRIES): 0]     ras_restore_ptr;
  reg                              ras_restore_is_empty;
  
  reg        predict_is_taken;
  reg [31:0] predicted_pc;
  reg [31:0] predicted_target_pc;

  //essentially two queues to temporarily hold instructions/PCs for instructions that arrive while pipeline is stalled
  reg [31:0] instr_valid [0:IMEM_INSTR_BUFFER_INTEGER_SIZE - 1];
  reg [31:0] pc_valid [0:IMEM_INSTR_BUFFER_INTEGER_SIZE - 1];
  
  reg [(RAS_ENTRIES << 5) - 1 : 0] ras_restore_stack_valid [0:IMEM_INSTR_BUFFER_INTEGER_SIZE - 1];
  reg [$clog2(RAS_ENTRIES): 0]     ras_restore_ptr_valid [0:IMEM_INSTR_BUFFER_INTEGER_SIZE - 1];
  reg                              ras_restore_is_empty_valid [0:IMEM_INSTR_BUFFER_INTEGER_SIZE - 1];
  
  reg        predict_is_taken_valid [0:IMEM_INSTR_BUFFER_INTEGER_SIZE - 1];
  reg [31:0] predicted_pc_valid [0:IMEM_INSTR_BUFFER_INTEGER_SIZE - 1];
  reg [31:0] predicted_target_pc_valid [0:IMEM_INSTR_BUFFER_INTEGER_SIZE - 1];
  
  reg [PTR_BITS - 1:0] pc_head;
  reg [PTR_BITS - 1:0] pc_tail;
  reg [IMEM_INSTR_BUFFER_BITS - 1:0] is_valid_and_halt_counter;
  //added queue to match returned instructions with their correct PC
  reg [31:0] request_pc [0:IMEM_INSTR_BUFFER_INTEGER_SIZE - 1];
  
  reg [(RAS_ENTRIES << 5) - 1 : 0] request_ras_restore_stack [0:IMEM_INSTR_BUFFER_INTEGER_SIZE - 1];
  reg [$clog2(RAS_ENTRIES): 0]     request_ras_restore_ptr [0:IMEM_INSTR_BUFFER_INTEGER_SIZE - 1];
  reg                              request_ras_restore_is_empty [0:IMEM_INSTR_BUFFER_INTEGER_SIZE - 1];
  
  reg        request_predict_is_taken [0:IMEM_INSTR_BUFFER_INTEGER_SIZE - 1];
  reg [31:0] request_predicted_pc [0:IMEM_INSTR_BUFFER_INTEGER_SIZE - 1];
  reg [31:0] request_predicted_target_pc [0:IMEM_INSTR_BUFFER_INTEGER_SIZE - 1];
  
  reg [PTR_BITS - 1:0] request_head;
  reg [PTR_BITS - 1:0] request_tail;
  reg [IMEM_INSTR_BUFFER_BITS - 1:0] request_count;
  //basically like a skip count
  reg [IMEM_INSTR_BUFFER_BITS - 1:0] discard_count;

  //cache hit, respond in same cycle
  wire immediate_response = i_imem_ren & i_imem_ready & i_imem_valid;
  //cache miss
  wire queue_push = i_imem_ren & i_imem_ready & ~i_imem_valid &
                    (request_count != IMEM_BUFFER_COUNT_MAX);
  wire queue_pop = write_en & ~halt &
                   (is_valid_and_halt_counter != {IMEM_INSTR_BUFFER_BITS{1'b0}});
  wire response_valid = i_imem_valid &
                        (discard_count == {IMEM_INSTR_BUFFER_BITS{1'b0}}) &
                        (immediate_response | (request_count != {IMEM_INSTR_BUFFER_BITS{1'b0}}));
  wire response_queued = response_valid & ~immediate_response;
  //flushed
  wire response_discard = i_imem_valid &
                          (discard_count != {IMEM_INSTR_BUFFER_BITS{1'b0}});
  //no waiting required, nothing in bugger pipeline not stalled
  wire response_to_output = response_valid & write_en & ~halt &
                            (is_valid_and_halt_counter == {IMEM_INSTR_BUFFER_BITS{1'b0}});
  wire response_to_buffer = response_valid & ~response_to_output;

  assign o_instr = instr;
  assign o_pc = pc;
  assign o_valid = valid;  // 3/25 UPDATE
  
  assign o_ras_restore_stack    =  ras_restore_stack;
  assign o_ras_restore_ptr      =  ras_restore_ptr;
  assign o_ras_restore_is_empty =  ras_restore_is_empty;
  
  assign o_predict_is_taken    = predict_is_taken;
  assign o_predicted_pc        = predicted_pc;
  assign o_predicted_target_pc = predicted_target_pc;
  
  
  assign o_buffer_empty = is_valid_and_halt_counter == {IMEM_INSTR_BUFFER_BITS{1'b0}};
  assign o_buffer_full = (is_valid_and_halt_counter == IMEM_BUFFER_COUNT_MAX) | (request_count == IMEM_BUFFER_COUNT_MAX);

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
    //clear everything
    if (i_rst) begin
      instr <= NOP_INSTRUCTION;
      pc <= RESET_ADDR;
      valid <= 1'b0;
      ras_restore_stack <= 'd0;
      ras_restore_ptr <= 'd0;
      ras_restore_is_empty <= 1'b1;
      predict_is_taken <= 1'b0;
      predicted_pc <= RESET_ADDR;
      predicted_target_pc <= RESET_ADDR;
      pc_head <= {PTR_BITS{1'b0}};
      pc_tail <= {PTR_BITS{1'b0}};
      is_valid_and_halt_counter <= {IMEM_INSTR_BUFFER_BITS{1'b0}};
      request_head <= {PTR_BITS{1'b0}};
      request_tail <= {PTR_BITS{1'b0}};
      request_count <= {IMEM_INSTR_BUFFER_BITS{1'b0}};
      discard_count <= {IMEM_INSTR_BUFFER_BITS{1'b0}};
    //flush on control flow change, but do not clear the buffer as these instructions may still be valid
    end else if (if_flush) begin
      instr <= NOP_INSTRUCTION;
      pc <= i_pc;
      valid <= 1'b0;
      ras_restore_stack <= 'd0;
      ras_restore_ptr <= 'd0;
      ras_restore_is_empty <= 1'b1;
      predict_is_taken <= 1'b0;
      predicted_pc <= i_pc;
      predicted_target_pc <= i_pc;
      pc_head <= {PTR_BITS{1'b0}};
      pc_tail <= {PTR_BITS{1'b0}};
      is_valid_and_halt_counter <= {IMEM_INSTR_BUFFER_BITS{1'b0}};
      //requests from the old path will still return, but they should be ignored
      discard_count <= queue_push ? (request_count + 1'b1) : request_count;
      request_head <= {PTR_BITS{1'b0}};
      request_tail <= {PTR_BITS{1'b0}};
      request_count <= {IMEM_INSTR_BUFFER_BITS{1'b0}};
    // push to buffer if new instruction is valid and pipeline is not stalled, pop from buffer if pipeline is not stalled and there are instructions in the buffer
    end else begin
      if (response_discard) begin
        discard_count <= discard_count - 1'b1;
      end else begin
        discard_count <= discard_count;
      end
      //new memory request
      if (queue_push) begin
        request_pc[request_tail] <= i_pc;
        request_ras_restore_stack[request_tail] <= i_ras_restore_stack;
        request_ras_restore_ptr[request_tail] <= i_ras_restore_ptr;
        request_ras_restore_is_empty[request_tail] <= i_ras_restore_is_empty;
        request_predict_is_taken[request_tail] <= i_predict_is_taken;
        request_predicted_pc[request_tail] <= i_predicted_pc;
        request_predicted_target_pc[request_tail] <= i_predicted_target_pc;
        request_tail <= request_tail + 1'b1;
      end else begin
        request_tail <= request_tail;
      end
      //dequeue
      if (response_queued) begin
        request_head <= request_head + 1'b1;
      end else begin
        request_head <= request_head;
      end
      //track number of valid requests
      case ({queue_push, response_queued})
        2'b10: request_count <= request_count + 1'b1;
        2'b01: request_count <= request_count - 1'b1;
        default: request_count <= request_count;
      endcase
      //cannot go directly to pipeline
      if (response_to_buffer) begin
        instr_valid[pc_tail] <= i_instr;
        pc_valid[pc_tail] <= immediate_response ? i_pc : request_pc[request_head];
        ras_restore_stack_valid[pc_tail] <= immediate_response ? i_ras_restore_stack : request_ras_restore_stack[request_head];
        ras_restore_ptr_valid[pc_tail] <= immediate_response ? i_ras_restore_ptr : request_ras_restore_ptr[request_head];
        ras_restore_is_empty_valid[pc_tail] <= immediate_response ? i_ras_restore_is_empty : request_ras_restore_is_empty[request_head];
        predict_is_taken_valid[pc_tail] <= immediate_response ? i_predict_is_taken : request_predict_is_taken[request_head];
        predicted_pc_valid[pc_tail] <= immediate_response ? i_predicted_pc : request_predicted_pc[request_head];
        predicted_target_pc_valid[pc_tail] <= immediate_response ? i_predicted_target_pc : request_predicted_target_pc[request_head];
        pc_tail <= pc_tail + 1'b1;
      end else begin
        pc_tail <= pc_tail;
      end

      if (queue_pop) begin
        pc_head <= pc_head + 1'b1;
      end else begin
        pc_head <= pc_head;
      end
      //track number of instructions
      case ({response_to_buffer, queue_pop})
        2'b10: is_valid_and_halt_counter <= is_valid_and_halt_counter + 1'b1;
        2'b01: is_valid_and_halt_counter <= is_valid_and_halt_counter - 1'b1;
        default: is_valid_and_halt_counter <= is_valid_and_halt_counter;
      endcase

      casez ({halt, write_en, response_to_output, queue_pop})
        //halt
        4'b1??? : begin
          instr <= NOP_INSTRUCTION;
          pc <= pc;
          valid <= 1'b0;  // 3/25 UPDATE
          ras_restore_stack <= ras_restore_stack;
          ras_restore_ptr <= ras_restore_ptr;
          ras_restore_is_empty <= ras_restore_is_empty;
          predict_is_taken <= 1'b0;
          predicted_pc <= predicted_pc;
          predicted_target_pc <= predicted_target_pc;
        end
        //normal
        4'b0110 : begin
          instr <= i_instr;
          pc <= immediate_response ? i_pc : request_pc[request_head];
          ras_restore_stack <= immediate_response ? i_ras_restore_stack : request_ras_restore_stack[request_head];
          ras_restore_ptr <= immediate_response ? i_ras_restore_ptr : request_ras_restore_ptr[request_head];
          ras_restore_is_empty <= immediate_response ? i_ras_restore_is_empty : request_ras_restore_is_empty[request_head];
          predict_is_taken <= immediate_response ? i_predict_is_taken : request_predict_is_taken[request_head];
          predicted_pc <= immediate_response ? i_predicted_pc : request_predicted_pc[request_head];
          predicted_target_pc <= immediate_response ? i_predicted_target_pc : request_predicted_target_pc[request_head];
          valid <= 1'b1;
        end
        //pipeline not stalled, buffered instruction first
        4'b0101 : begin
          instr <= instr_valid[pc_head];
          pc <= pc_valid[pc_head];
          ras_restore_stack <= ras_restore_stack_valid[pc_head];
          ras_restore_ptr <= ras_restore_ptr_valid[pc_head];
          ras_restore_is_empty <= ras_restore_is_empty_valid[pc_head];
          predict_is_taken <= predict_is_taken_valid[pc_head];
          predicted_pc <= predicted_pc_valid[pc_head];
          predicted_target_pc <= predicted_target_pc_valid[pc_head];
          valid <= 1'b1;
        end
        //empty queue
        4'b0100 : begin
          instr <= NOP_INSTRUCTION;
          pc <= pc;
          ras_restore_stack <= ras_restore_stack;
          ras_restore_ptr <= ras_restore_ptr;
          ras_restore_is_empty <= ras_restore_is_empty;
          predict_is_taken <= 1'b0;
          predicted_pc <= predicted_pc;
          predicted_target_pc <= predicted_target_pc;
          valid <= 1'b0;
        end
        default : begin
          instr <= instr;
          pc <= pc;
          ras_restore_stack <= ras_restore_stack;
          ras_restore_ptr <= ras_restore_ptr;
          ras_restore_is_empty <= ras_restore_is_empty;
          predict_is_taken <= predict_is_taken;
          predicted_pc <= predicted_pc;
          predicted_target_pc <= predicted_target_pc;
          valid <= valid;
        end
      endcase
    end
  end
endmodule
