`timescale 1ns / 1ps
`define pc_counter(index) pc_counters[((index) << 1) +: 2]
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 01.05.2026 16:43:44
// Design Name: 
// Module Name: branch_history_table
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


module branch_history_table #(
  parameter HISTORY_BUFFER_ENTRY_SIZE = 4096
) (
  input  wire        i_rst,
  input  wire        i_clk,
  input  wire [31:0] pc_fetched,
  input  wire [31:0] branch_jumped_branched_pc,
  input  wire        branch_is_updated,
  input  wire        branch_update_taken,

  output wire        is_branch_predicted
);
  
  // In theory, this can be 13:2 if compressed instructions are not used
  // $clog2 won't work with a power of 2
  wire [$clog2(HISTORY_BUFFER_ENTRY_SIZE) - 1:0] updated_index = branch_jumped_branched_pc[$clog2(HISTORY_BUFFER_ENTRY_SIZE) + 1:2];
  wire [$clog2(HISTORY_BUFFER_ENTRY_SIZE) - 1:0] fetched_index = pc_fetched[$clog2(HISTORY_BUFFER_ENTRY_SIZE) + 1:2];
  
  reg [(HISTORY_BUFFER_ENTRY_SIZE << 1) - 1 : 0] pc_counters = {HISTORY_BUFFER_ENTRY_SIZE{2'b10}};

  // Real memory adheres to a read-first or write-first policy (like BRAM)
  // So in reality this should be placed into the always block.
  assign is_branch_predicted = (`pc_counter(fetched_index) == 2'b10) | (`pc_counter(fetched_index) == 2'b11);
  
  always @(posedge i_clk) begin
    casez ({i_rst, branch_is_updated})
      2'b1? : pc_counters <= {HISTORY_BUFFER_ENTRY_SIZE{2'b10}};
      2'b01 : `pc_counter(updated_index)  <= branch_update_taken & (`pc_counter(updated_index) == 2'b11) ? `pc_counter(updated_index)
                                            : (~branch_update_taken) & (`pc_counter(updated_index) == 2'b00) ? `pc_counter(updated_index)
                                            : branch_update_taken & (`pc_counter(updated_index) != 2'b11) ? `pc_counter(updated_index) + 2'd1
                                            : `pc_counter(updated_index) - 2'd1;
      default : pc_counters <= pc_counters;
    endcase
  end
endmodule
