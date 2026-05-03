`timescale 1ns / 1ps

module fetch #(
  parameter RESET_ADDR = 32'h00000000,
  parameter RAS_ENTRIES = 32
) (
  input  wire        i_clk,
  input  wire        i_rst,
  input  wire        halt,
  
  input  wire [31:0] branch_corrected_target,
  input  wire [31:0] branch_jumped_branched_pc,
  
  input  wire [31:0] branch_recovery_pc,
  input  wire        branch_recovery_needed,
  
  input  wire        branch_is_updated,
  input  wire        branch_update_taken,
  
  input  wire        is_branch_instr,
  input  wire        is_jal_instr,
  input  wire        is_jalr_instr,
  
  input  wire        pc_write_en,
  input  wire        i_imem_ready,
  input  wire        if_id_buffer_full,
  
  input  wire [ 4:0] jump_rd_raddr,
  input  wire [ 4:0] jump_rs1_raddr,
  
  input  wire [(RAS_ENTRIES << 5) - 1 : 0] i_ras_restore_stack,
  input  wire [$clog2(RAS_ENTRIES): 0]     i_ras_restore_ptr,
  input  wire                              i_ras_restore_is_empty,
    
  output wire        predict_is_taken,
  output wire [31:0] predicted_pc,
  output wire [31:0] predicted_target_pc,
  
  output wire [31:0] pc,
  output wire [31:0] pc_plus_4,
  output wire        o_imem_ren,
  
  output wire [(RAS_ENTRIES << 5) - 1 : 0] o_ras_current_stack,
  output wire [$clog2(RAS_ENTRIES): 0]     o_ras_current_ptr,
  output wire                              o_ras_current_is_empty
);

  reg [31:0] pc_reg; // The PC register from the schematic
  
  assign pc = pc_reg;
  assign pc_plus_4 = pc_reg + 32'd4; // The output wire of the adder for PC + 4
  assign o_imem_ren = (~i_rst) & (~halt) & pc_write_en & i_imem_ready & (~if_id_buffer_full);
  
  wire is_branch_predicted;
  
  wire is_jump_instr = is_jal_instr | is_jalr_instr;
  
  branch_history_table #(
    .HISTORY_BUFFER_ENTRY_SIZE(4096)
  ) branch_history_table (
    .i_clk(i_clk),
    .i_rst(i_rst),
    .pc_fetched(pc_reg),
    .branch_jumped_branched_pc(branch_jumped_branched_pc),
    .branch_is_updated(branch_is_updated & is_branch_instr),
    .branch_update_taken(branch_update_taken),
    .is_branch_predicted(is_branch_predicted)
  );
  
  localparam [2:0] BTB_INSTR_BRANCH = 3'd0;
  localparam [2:0] BTB_INSTR_JUMP   = 3'd1;
  localparam [2:0] BTB_INSTR_CALL   = 3'd2;
  localparam [2:0] BTB_INSTR_RETURN = 3'd3;
  localparam [2:0] BTB_INSTR_SWAP   = 3'd4;

  
  wire [2:0] i_updated_type = (is_branch_instr)                                                                                                                                                       ? BTB_INSTR_BRANCH
                            : (is_jal_instr  & (jump_rd_raddr == 5'd1 | jump_rd_raddr == 5'd5))                                                                                                       ? BTB_INSTR_CALL
                            : (is_jal_instr)                                                                                                                                                          ? BTB_INSTR_JUMP
                            : (is_jalr_instr & (jump_rd_raddr != 5'd1 & jump_rd_raddr != 5'd5) & (jump_rs1_raddr != 5'd1 & jump_rs1_raddr != 5'd5))                                                   ? BTB_INSTR_JUMP
                            : (is_jalr_instr & (jump_rd_raddr != 5'd1 & jump_rd_raddr != 5'd5) & (jump_rs1_raddr == 5'd1 | jump_rs1_raddr == 5'd5))                                                   ? BTB_INSTR_RETURN
                            : (is_jalr_instr & (jump_rd_raddr == 5'd1 | jump_rd_raddr == 5'd5) & (jump_rs1_raddr != 5'd1 & jump_rs1_raddr != 5'd5))                                                   ? BTB_INSTR_CALL
                            : (is_jalr_instr & (jump_rd_raddr == jump_rs1_raddr)               & (jump_rs1_raddr == 5'd1 | jump_rs1_raddr == 5'd5))                                                   ? BTB_INSTR_CALL
                            : (is_jalr_instr & (jump_rd_raddr != jump_rs1_raddr)               & (jump_rs1_raddr == 5'd1 | jump_rs1_raddr == 5'd5) & (jump_rd_raddr == 5'd1 | jump_rd_raddr == 5'd5)) ? BTB_INSTR_SWAP
                            : BTB_INSTR_JUMP;
  
  wire        is_pc_in_btb;
  wire [31:0] pc_from_btb;
  wire [ 2:0] target_type;
  
    
  branch_target_buffer branch_target_buffer (
    .i_clk(i_clk),
    .i_rst(i_rst),
    
    .i_is_update(branch_is_updated & branch_update_taken),
    
    .i_pc_fetched(pc_reg),
    
    .i_pc_updated(branch_jumped_branched_pc),
    .i_updated_target(branch_corrected_target),
    .i_updated_type(i_updated_type),
    
    .o_is_hit(is_pc_in_btb),
    .o_pc_next(pc_from_btb),
    .o_instr_type(target_type)
  );
  
  wire [31:0] ras_pc = branch_recovery_needed ? branch_jumped_branched_pc : pc_reg;
  wire is_ras_return;
  wire [31:0] ras_return_addr;
  
  wire if_id_can_queue = o_imem_ren & (~if_id_buffer_full) & (~branch_recovery_needed);
    
  wire ras_is_pop  = (if_id_can_queue & is_pc_in_btb & (target_type == BTB_INSTR_RETURN | target_type == BTB_INSTR_SWAP))
                   | (branch_is_updated & branch_recovery_needed & (i_updated_type == BTB_INSTR_RETURN | i_updated_type == BTB_INSTR_SWAP));
  
  wire ras_is_push = (if_id_can_queue & is_pc_in_btb & (target_type == BTB_INSTR_CALL | target_type == BTB_INSTR_SWAP))
                   | (branch_is_updated & branch_recovery_needed & (i_updated_type == BTB_INSTR_CALL | i_updated_type == BTB_INSTR_SWAP));
  
  wire i_restore_state = branch_recovery_needed;
  
  return_address_stack return_address_stack (
    .i_clk(i_clk),
    .i_rst(i_rst),
    .i_is_push(ras_is_push),
    .i_is_pop(ras_is_pop),
    
    .i_restore_state(i_restore_state),
    
    .i_restore_stack(i_ras_restore_stack),
    .i_restore_ptr(i_ras_restore_ptr),
    .i_restore_is_empty(i_ras_restore_is_empty),
    
    .pc(ras_pc),
    .is_return(is_ras_return),
    .return_addr(ras_return_addr),
    
    .o_current_stack(o_ras_current_stack),
    .o_current_ptr(o_ras_current_ptr),
    .o_current_is_empty(o_ras_current_is_empty)
  );
  
  assign predict_is_taken = (is_pc_in_btb & target_type != BTB_INSTR_BRANCH) | (is_pc_in_btb & target_type == BTB_INSTR_BRANCH & is_branch_predicted);
    
  assign predicted_target_pc = (is_pc_in_btb & is_ras_return & (target_type == BTB_INSTR_RETURN | target_type == BTB_INSTR_SWAP)) ? ras_return_addr : pc_from_btb;
  
  assign predicted_pc = predict_is_taken ? predicted_target_pc : pc_plus_4;

  
  
  always @(posedge i_clk) begin
		if (i_rst) begin
			pc_reg <= RESET_ADDR;
    end else if (branch_recovery_needed) begin
			pc_reg <= branch_recovery_pc;
		end else if (halt) begin // prioritize control flow 
			pc_reg <= pc_reg;
    end else if ((~pc_write_en) | (~i_imem_ready) | if_id_buffer_full) begin
      pc_reg <= pc_reg;
    end else begin
      pc_reg <= predicted_pc;
    end 
  end
    
endmodule