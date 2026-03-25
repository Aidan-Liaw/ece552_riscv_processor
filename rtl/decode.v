`timescale 1ns / 1ps

`default_nettype wire

module decode (
  input  wire        i_clk,
  input  wire        i_rst,
  
  input  wire [31:0] i_instr,
  input  wire [31:0] i_pc,
  
  input  wire [31:0] id_forward_data_rs1,
  input  wire [31:0] id_forward_data_rs2,
  input  wire [ 1:0] id_forward_sel,

  input  wire [ 4:0] id_ex_rd,
  input  wire        id_ex_reg_write,
  input  wire        id_ex_mem_read,
  input  wire [ 4:0] ex_mem_rd,
  input  wire        ex_mem_mem_read,
  input  wire        ex_mem_reg_write,
  input  wire [ 4:0] mem_wb_rd,
  input  wire        mem_wb_reg_write,
  input  wire [31:0] writeback_data,
  
  input  wire        keep_halting,

  output wire [31:0] o_next_pc,
  output wire        o_is_jump,
  output wire        o_is_branch,
  output wire        o_is_jump_or_branch,
  
  // Register data
  output wire [31:0] rs1_data,
  output wire [31:0] rs2_data,
  
  // Control Unit wires
  // Execute stage control
  output wire [31:0] imm_val,
  output wire        pc_add, // 0 for rs1_data, 1 for PC
  output wire        alu_src, // 0 for rs2_data, 1 for immediate
  output wire [ 4:0] alu_opsel, // ALU Control Signal
  // Memory stage/Data Memory control
  output wire        dmem_read_en,
  output wire        dmem_write_en,
  output wire [ 2:0] funct3,
  // Writeback stage control
  output wire        reg_write_en, // Regiser File control
  output wire [ 1:0] register_write_sel, 
  
  output wire        if_id_write_en,
  output wire        pc_write_en,
  output wire        cu_passthrough_en,
  
  output wire        if_flush,
  output wire        id_flush,
  output wire        ex_flush,
  output wire        mem_flush,
  
  output wire        halt_generate,
  output wire        trap_control_unit
);

  // instruction decoding wires
  wire [6:0]  opcode = i_instr[6:0];
  wire [4:0]  rd     = i_instr[11:7];
  assign      funct3 = i_instr[14:12]; // Defined in module ports as needed by future stage
  wire [4:0]  rs1    = i_instr[19:15];
  wire [4:0]  rs2    = i_instr[24:20];
  wire [6:0]  funct7 = i_instr[31:25];
  
  // Data wires 
  // imm_value is defined in the module ports, output from Immediate Generation
  wire [ 5:0] imm_format;

  // rs1_data, rs2_data are defined in the module ports, output from RF from registers' data
  
  //// Control Unit wires 
  // Fetch/Flow control
  wire branch; // 0 for non-branch instructions, 1 for branch instructions
  wire jump; // 0 for non-jump instructions, 1 for jump instructions

  wire cu_if_flush;
  	
  control_unit ctrl (
    // Inputs
    .i_rst(i_rst),
    .opcode(opcode),
    .funct3(funct3),
    .funct7(funct7),
    .rs2(rs2),
    .keep_halting(keep_halting),
    
    // IF Signals
    .branch(branch),
    .jump(jump),
    
    // EX Signals
    .imm_format(imm_format),
    .pc_add(pc_add),
    .alu_src(alu_src),
    .alu_opsel(alu_opsel),
    
    // MEM Signals
    .mem_read_en(dmem_read_en),
    .mem_write_en(dmem_write_en),
    // funct3[2:0] passthrough seen in schematic
    
    // WB Signals
    .reg_write_en(reg_write_en),
    .write_reg_sel(register_write_sel),
    
    // Flush Signals
    .if_flush(cu_if_flush),
    .id_flush(id_flush),
    .ex_flush(ex_flush),
    .mem_flush(mem_flush),
    
    // Global Signals
    .halt_generate(halt_generate),
    .trap(trap_control_unit)
  );
  	
  ///// branch and next pc logic /////
  wire is_branch_taken;
  //slight fix 
  wire [31:0] register_jump_base_address = id_forward_sel[0] ? id_forward_data_rs1 : rs1_data;
  wire [31:0] register_jump_target  = (register_jump_base_address + imm_val) & 32'hFFFFFFFE; // Clears LSBit
  wire [31:0] immediate_jump_target = i_pc + imm_val;
	
	// TODO:
	wire [31:0] rs1_branch = id_forward_sel[0] ? id_forward_data_rs1 : rs1_data;

    wire [31:0] rs2_branch = id_forward_sel[1] ? id_forward_data_rs2 : rs2_data;
	branch_condition_checker branch_condition_checker(i_rst, branch, funct3, rs1_branch, rs2_branch, is_branch_taken);
	
  // only trigger a jump if the branch is taken and the pipeline is not stalled
  assign o_is_jump = jump;  // 3/25 UPDATE: removed '& cu_passthrough_en;'
  assign o_is_branch = branch;  // 3/25 UPDATE: removed '& is_branch_taken & cu_passthrough_en;'
  assign o_is_jump_or_branch = ((branch & is_branch_taken) | jump) & cu_passthrough_en;

  // safely combine the cu flush with our jump flush
  assign if_flush = cu_if_flush | o_is_jump_or_branch;

	next_pc_setter next_pc_setter(i_pc, opcode, is_branch_taken, jump, 
	 register_jump_target, immediate_jump_target, o_next_pc);

	branch_hazard_detector branch_hazard_detector(
	  .i_rst(i_rst),
    .instr(i_instr),
    .imm_format(imm_format),
    .id_ex_mem_read(id_ex_mem_read),
    .id_ex_rd(id_ex_rd),
    .id_ex_reg_write(id_ex_reg_write),
    .ex_mem_mem_read(ex_mem_mem_read),
    .ex_mem_rd(ex_mem_rd),
    .ex_mem_reg_write(ex_mem_reg_write), 
    .if_id_write_en(if_id_write_en),
    .pc_write_en(pc_write_en),
    .cu_passthrough_en(cu_passthrough_en)
  );
		
    /* CHANGED: 
     * .rd_waddr(rd) to .rd_waddr(mem_wb_rd) 
     * .rd_en(reg_write_en) to .rd_en(mem_wb_reg_write)
     */
  regfile #( .BYPASS_EN(1)) rf (
    .clk(i_clk), .rst(i_rst), .rs1_raddr(rs1), .rs2_raddr(rs2), .rd_waddr(mem_wb_rd), .rd_wdata(writeback_data),
		.rd_wen(mem_wb_reg_write), .rs1_rdata(rs1_data), .rs2_rdata(rs2_data)
	);
	
  imm_gen ig (.instr(i_instr), .instr_format(imm_format), .immediate(imm_val));

  //assign if_flush = cu_if_flush | o_is_jump_or_branch;
 
	
endmodule
