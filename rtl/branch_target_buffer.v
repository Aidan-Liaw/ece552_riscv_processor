`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02.05.2026 00:03:56
// Design Name: 
// Module Name: branch_target_buffer
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


module branch_target_buffer (
  // Global clock.
  input  wire        i_clk,
  // Synchronous active-high reset.
  input  wire        i_rst,

  input  wire        i_is_update,

  input  wire [31:0] i_pc_fetched,
  input  wire [31:0] i_pc_updated,
  input  wire [31:0] i_updated_target,
  input  wire [ 2:0] i_updated_type,
  
  output wire        o_is_hit,
  output wire [31:0] o_pc_next,
  output wire [ 2:0] o_instr_type
);
  // These parameters are equivalent to those provided in the project
  // 6 specification. Feel free to use them, but hardcoding these numbers
  // rather than using the localparams is also permitted, as long as the
  // same values are used (and consistent with the project specification).
  //
  // 512 sets * 2 ways per set = 1K entries
  localparam O = 2;            // 2 bit offset
  localparam S = 9;            // 9 bit set index => 512 sets
  localparam DEPTH = 512;      // 512 sets
  localparam W = 2;            // 2 way set associative, NMRU
  localparam T = 32 - O - S;   // 21 bit tag
    
  // The following memory arrays model the cache structure. As this is
  // an internal implementation detail, you are *free* to modify these
  // arrays as you please.

  // Backing memory, modeled as two separate ways.
  reg [   31:0] target0 [DEPTH - 1:0];
  reg [   31:0] target1 [DEPTH - 1:0];
  reg [T - 1:0] tags0   [DEPTH - 1:0];
  reg [T - 1:0] tags1   [DEPTH - 1:0];
  reg [DEPTH - 1:0] valid0;
  reg [DEPTH - 1:0] valid1;
  localparam TYPE_DEPTH = 1536;   // 512 sets * 3
  reg [TYPE_DEPTH - 1:0] type0;
  reg [TYPE_DEPTH - 1:0] type1;
  reg [DEPTH - 1:0] lru;
  
  
  //decode incoming address and check for hits, current CPU request
  wire [S-1:0] fetched_index  = i_pc_fetched[O+S-1:O];
  wire [T-1:0] fetched_tag    = i_pc_fetched[31:O+S];

  wire hit0 = valid0[fetched_index] && (tags0[fetched_index] == fetched_tag);
  wire hit1 = valid1[fetched_index] && (tags1[fetched_index] == fetched_tag);
  wire hit  = hit0 || hit1;
  
  assign o_is_hit = hit;
  
  wire [31:0] word0 = target0[fetched_index];
  wire [31:0] word1 = target1[fetched_index];
  
  
  wire [S-1:0] req_index  = i_pc_updated[O+S-1:O];
  wire [T-1:0] req_tag    = i_pc_updated[31:O+S];
  
  wire req_hit0 = valid0[req_index] && (tags0[req_index] == req_tag);
  wire req_hit1 = valid1[req_index] && (tags1[req_index] == req_tag);

  //use invalid way first, otherwise NMRU bit
  wire victim = !valid0[req_index] ? 1'b0
              : !valid1[req_index] ? 1'b1
              : lru[req_index];
  
  assign o_pc_next = hit == 1'b1 ? (hit0 ? word0 : word1) : 32'd0;
  
  assign o_instr_type = hit == 1'b1 ? (hit0 ? type0[((fetched_index << 1) + fetched_index) +: 3] : type1[((fetched_index << 1) + fetched_index) +: 3]) : 3'd0;
  
  
  //sequential logic
  always @(posedge i_clk) begin
    if (i_rst) begin
      valid0 <= {DEPTH{1'b0}};
      valid1 <= {DEPTH{1'b0}};
      lru <= {DEPTH{1'b0}};
    end else begin
      case (i_is_update)
        1'b1: begin
          target0[req_index] <= req_hit0 | (~victim & ~req_hit1) ? i_updated_target : target0[req_index];
          target1[req_index] <= req_hit1 | (victim & ~req_hit0)  ? i_updated_target : target1[req_index];

          tags0[req_index] <= (~victim & ~req_hit0 & ~req_hit1) ? req_tag : tags0[req_index];
          tags1[req_index] <= (victim & ~req_hit0 & ~req_hit1)  ? req_tag : tags1[req_index];
                    
          valid0[req_index] <= (~victim & ~req_hit0 & ~req_hit1) ? 1'b1 : valid0[req_index];
          valid1[req_index] <= (victim & ~req_hit0 & ~req_hit1)  ? 1'b1 : valid1[req_index];
          
          type0[((req_index << 1) + req_index) +: 3] <= req_hit0 | (~victim & ~req_hit1) ? i_updated_type : type0[((req_index << 1) + req_index) +: 3];
          type1[((req_index << 1) + req_index) +: 3] <= req_hit1 | (victim & ~req_hit0)  ? i_updated_type : type1[((req_index << 1) + req_index) +: 3];
          
          lru[req_index] <= req_hit0 | (~victim & ~req_hit1) ? 1'b1 : 1'b0;
        end
        default: begin
          case ({hit0, hit1})
            2'b10: lru[fetched_index] <= 1'b1;
            2'b01: lru[fetched_index] <= 1'b0;
            default: lru[fetched_index] <= lru[fetched_index];
          endcase
        end
      endcase

    end
  end

endmodule

`default_nettype wire
