`timescale 1ns / 1ps

`default_nettype wire

module hart #(
    // After reset, the program counter (PC) should be initialized to this
    // address and start executing instructions from there.
    parameter RESET_ADDR = 32'h00000000
) (    
    // Global clock.
    input  wire        i_clk,
    // Synchronous active-high reset.
    input  wire        i_rst,
    // Instruction fetch goes through a read only instruction memory (imem)
    // port. The port accepts a 32-bit address (e.g. from the program counter)
    // per cycle and combinationally returns a 32-bit instruction word. This
    // is not representative of a realistic memory interface; it has been
    // modeled as more similar to a DFF or SRAM to simplify phase 3. In
    // later phases, you will replace this with a more realistic memory.
    //
    // 32-bit read address for the instruction memory. This is expected to be
    // 4 byte aligned - that is, the two LSBs should be zero.
    output wire [31:0] o_imem_raddr,
    // Instruction word fetched from memory, available on the same cycle.
    input  wire [31:0] i_imem_rdata,
    // Data memory accesses go through a separate read/write data memory (dmem)
    // that is shared between read (load) and write (stored). The port accepts
    // a 32-bit address, read or write enable, and mask (explained below) each
    // cycle. Reads are combinational - values are available immediately after
    // updating the address and asserting read enable. Writes occur on (and
    // are visible at) the next clock edge.
    //
    // Read/write address for the data memory. This should be 32-bit aligned
    // (i.e. the two LSB should be zero). See `o_dmem_mask` for how to perform
    // half-word and byte accesses at unaligned addresses.
    output wire [31:0] o_dmem_addr,
    // When asserted, the memory will perform a read at the aligned address
    // specified by `i_addr` and return the 32-bit word at that address
    // immediately (i.e. combinationally). It is illegal to assert this and
    // `o_dmem_wen` on the same cycle.
    output wire        o_dmem_ren,
    // When asserted, the memory will perform a write to the aligned address
    // `o_dmem_addr`. When asserted, the memory will write the bytes in
    // `o_dmem_wdata` (specified by the mask) to memory at the specified
    // address on the next rising clock edge. It is illegal to assert this and
    // `o_dmem_ren` on the same cycle.
    output wire        o_dmem_wen,
    // The 32-bit word to write to memory when `o_dmem_wen` is asserted. When
    // write enable is asserted, the byte lanes specified by the mask will be
    // written to the memory word at the aligned address at the next rising
    // clock edge. The other byte lanes of the word will be unaffected.
    output wire [31:0] o_dmem_wdata,
    // The dmem interface expects word (32 bit) aligned addresses. However,
    // WISC-25 supports byte and half-word loads and stores at unaligned and
    // 16-bit aligned addresses, respectively. To support this, the access
    // mask specifies which bytes within the 32-bit word are actually read
    // from or written to memory.
    //
    // To perform a half-word read at address 0x00001002, align `o_dmem_addr`
    // to 0x00001000, assert `o_dmem_ren`, and set the mask to 0b1100 to
    // indicate that only the upper two bytes should be read. Only the upper
    // two bytes of `i_dmem_rdata` can be assumed to have valid data; to
    // calculate the final value of the `lh[u]` instruction, shift the rdata
    // word right by 16 bits and sign/zero extend as appropriate.
    //
    // To perform a byte write at address 0x00002003, align `o_dmem_addr` to
    // `0x00002000`, assert `o_dmem_wen`, and set the mask to 0b1000 to
    // indicate that only the upper byte should be written. On the next clock
    // cycle, the upper byte of `o_dmem_wdata` will be written to memory, with
    // the other three bytes of the aligned word unaffected. Remember to shift
    // the value of the `sb` instruction left by 24 bits to place it in the
    // appropriate byte lane.
    output wire [ 3:0] o_dmem_mask,
    // The 32-bit word read from data memory. When `o_dmem_ren` is asserted,
    // this will immediately reflect the contents of memory at the specified
    // address, for the bytes enabled by the mask. When read enable is not
    // asserted, or for bytes not set in the mask, the value is undefined.
    input  wire [31:0] i_dmem_rdata,
	// The output `retire` interface is used to signal to the testbench that
    // the CPU has completed and retired an instruction. A single cycle
    // implementation will assert this every cycle; however, a pipelined
    // implementation that needs to stall (due to internal hazards or waiting
    // on memory accesses) will not assert the signal on cycles where the
    // instruction in the writeback stage is not retiring.
    //
    // Asserted when an instruction is being retired this cycle. If this is
    // not asserted, the other retire signals are ignored and may be left invalid.
    output wire        o_retire_valid,
    // The 32 bit instruction word of the instrution being retired. This
    // should be the unmodified instruction word fetched from instruction
    // memory.
    output wire [31:0] o_retire_inst,
    // Asserted if the instruction produced a trap, due to an illegal
    // instruction, unaligned data memory access, or unaligned instruction
    // address on a taken branch or jump.
    output wire        o_retire_trap,
    // Asserted if the instruction is an `ebreak` instruction used to halt the
    // processor. This is used for debugging and testing purposes to end
    // a program.
    output wire        o_retire_halt,
    // The first register address read by the instruction being retired. If
    // the instruction does not read from a register (like `lui`), this
    // should be 5'd0.
    output wire [ 4:0] o_retire_rs1_raddr,
    // The second register address read by the instruction being retired. If
    // the instruction does not read from a second register (like `addi`), this
    // should be 5'd0.
    output wire [ 4:0] o_retire_rs2_raddr,
    // The first source register data read from the register file (in the
    // decode stage) for the instruction being retired. If rs1 is 5'd0, this
    // should also be 32'd0.
    output wire [31:0] o_retire_rs1_rdata,
    // The second source register data read from the register file (in the
    // decode stage) for the instruction being retired. If rs2 is 5'd0, this
    // should also be 32'd0.
    output wire [31:0] o_retire_rs2_rdata,
    // The destination register address written by the instruction being
    // retired. If the instruction does not write to a register (like `sw`),
    // this should be 5'd0.
    output wire [ 4:0] o_retire_rd_waddr,
    // The destination register data written to the register file in the
    // writeback stage by this instruction. If rd is 5'd0, this field is
    // ignored and can be treated as a don't care.
    output wire [31:0] o_retire_rd_wdata,
    // The current program counter of the instruction being retired - i.e.
    // the instruction memory address that the instruction was fetched from.
    
    output wire [31:0] o_retire_dmem_addr,
    output wire        o_retire_dmem_ren,
    output wire        o_retire_dmem_wen,
    output wire [ 3:0] o_retire_dmem_mask,
    output wire [31:0] o_retire_dmem_wdata,
    output wire [31:0] o_retire_dmem_rdata,

    
    output wire [31:0] o_retire_pc,
    // the next program counter after the instruction is retired. For most
    // instructions, this is `o_retire_pc + 4`, but must be the branch or jump
    // target for *taken* branches and jumps.
    output wire [31:0] o_retire_next_pc
`ifdef RISCV_FORMAL
    ,`RVFI_OUTPUTS,
`endif
);
  wire        halt;
	
	wire [31:0] if_pc;
	wire [31:0] if_pc_plus_4;
	wire        if_halt; // ?
	
  wire        pc_write_en;
  
  wire [31:0] wb_next_pc;
	
	fetch  #(
    .RESET_ADDR(32'h00000000)
  ) fetch (
    .i_clk(i_clk),
    .i_rst(i_rst),
    .halt(halt),
    
    .next_pc(wb_next_pc),
    .pc_write_en(pc_write_en),
    
    .pc(if_pc),
    .pc_plus_4(if_pc_plus_4)
  );

	assign o_imem_raddr = if_pc;
	
	wire        if_flush;
  wire        if_id_write_en;
  wire [31:0] if_id_instr = i_imem_rdata;
  
  wire [31:0] id_instr;
  wire [31:0] id_pc;
  
  if_id_registers #(
    .NOP_INSTRUCTION(32'h00000013)
  ) if_id_registers (
    .i_clk(i_clk),
    .halt(halt),
    .if_flush(if_flush),
    .write_en(if_id_write_en),
    
    .i_instr(if_id_instr),
    .i_pc(if_pc),

    .o_instr(id_instr),
    .o_pc(id_pc)
  );
  
  // id_instr, id_pc, are all defined earlier
  wire [31:0] id_next_pc;
  
  wire [31:0] id_rs1_data;
  wire [31:0] id_rs2_data;
  
  wire        keep_halting;
  
  wire [31:0] id_imm_val;
  wire        id_pc_add;
  wire        id_alu_src;
  wire [ 4:0] id_alu_opsel;
  
  wire        id_dmem_read_en;
  wire        id_dmem_write_en;
  wire [ 2:0] id_funct3;
  
  wire        id_reg_write_en;
  wire [ 1:0] id_register_write_sel;
  
  // if_id_write_en is defined earlier
  // pc_write_en is defined earlier
  wire        cu_passthrough_en;
  
  // if_flush is defined earlier
  wire        id_flush;
  wire        ex_flush;
  wire        mem_flush;
  
  wire        trap_control_unit;

  wire [31:0] ex_instr;
  wire        ex_halt;
  wire        ex_dmem_read_en;
  wire        ex_reg_write_en;
  wire [ 4:0] ex_rd = (ex_instr == 7'b010_0011) | (ex_instr == 7'b110_0011) 
                       ? ex_instr[11:7] 
                       : 7'd0;
                       
  wire [31:0] mem_instr;
  wire        mem_halt;
  wire        mem_dmem_read_en;
  wire        mem_reg_write_en;
  wire [ 4:0] mem_rd = (mem_instr == 7'b010_0011) | (mem_instr == 7'b110_0011) 
                        ? mem_instr[11:7] 
                        : 7'd0;
   
  wire [31:0] wb_instr;
  wire        wb_halt;
  wire        wb_reg_write_en;
  wire [ 4:0] wb_rd = (wb_instr == 7'b010_0011) | (wb_instr == 7'b110_0011) 
                     ? wb_instr[11:7] 
                     : 7'd0;
                     
  wire [31:0] writeback_data;

  decode decode (
    .i_clk(i_clk),
    .i_rst(i_rst),
    
    .i_instr(id_instr),
    .i_pc(id_pc),

//    .id_ex_mem_read(ex_dmem_read_en),
    .id_ex_rd(ex_rd),
    .id_ex_reg_write(ex_reg_write_en),
    
    .ex_mem_rd(mem_rd),
    .ex_mem_reg_write(mem_reg_write_en),
    
    .mem_wb_rd(wb_rd),
    .mem_wb_reg_write(wb_reg_write_en),
    
    .writeback_data(writeback_data),
    
    .keep_halting(keep_halting),


    .o_instr(id_instr),
    .o_pc(id_pc),
    .o_next_pc(id_next_pc),

    // Register data
    .rs1_data(id_rs1_data),
    .rs2_data(id_rs2_data),


    .imm_val(id_imm_val),
    .pc_add(id_pc_add), // 0 for rs1_data, 1 for PC
    .alu_src(id_alu_src), // 0 for rs2_data, 1 for immediate
    .alu_opsel(id_alu_opsel), // ALU Control Signal

    .dmem_read_en(id_dmem_read_en),
    .dmem_write_en(id_dmem_write_en),
    .funct3(id_funct3),

    .reg_write_en(id_reg_write_en), // Regiser File control
    .register_write_sel(id_register_write_sel), 

    .if_id_write_en(if_id_write_en),
    .pc_write_en(pc_write_en),
    .cu_passthrough_en(cu_passthrough_en),

    .if_flush(if_flush),
    .id_flush(id_flush),
    .ex_flush(ex_flush),
    .mem_flush(mem_flush),

    .halt_generate(halt),
    .trap_control_unit(trap_control_unit)
  );
  
  // ex_instr is defined earlier
  wire [31:0] ex_pc;
  wire [31:0] ex_next_pc;
  
  wire        ex_is_halting;

  wire [31:0] ex_rs1_data;
  wire [31:0] ex_rs2_data;

  wire [31:0] ex_imm_val;
  wire        ex_pc_add;
  wire        ex_alu_src;
  wire [ 4:0] ex_alu_opsel;

  // ex_dmem_read_en is defined earlier
  wire        ex_dmem_write_en;
  wire [ 2:0] ex_funct3;

  // ex_reg_write_en is defined earlier
  wire [ 1:0] ex_register_write_sel;
  wire        ex_is_retiring;


  id_ex_registers #(
    .NOP_INSTRUCTION(32'h00000013)
  ) id_ex_registers (
    .i_clk(i_clk),
    
    .i_instr(id_instr),
    .i_pc(id_pc),
    .i_next_pc(id_next_pc),
    
    .id_flush(id_flush),
    .cu_passthrough_en(cu_passthrough_en),
    .i_is_halting(halt),

    
    .i_rs1_data(id_rs1_data),
    .i_rs2_data(id_rs2_data),
    
    
    .i_imm_val(id_imm_val),
    .i_pc_add(id_pc_add), // 0 for rs1_data, 1 for PC
    .i_alu_src(id_alu_src), // 0 for rs2_data, 1 for immediate
    .i_alu_opsel(id_alu_opsel), // ALU Control Signal

    .i_dmem_read_en(id_dmem_read_en),
    .i_dmem_write_en(id_dmem_write_en),
    .i_funct3(id_funct3),

    .i_reg_write_en(id_reg_write_en), // Regiser File control
    .i_register_write_sel(id_register_write_sel),    


    .o_instr(ex_instr),
    .o_pc(ex_pc),
    .o_next_pc(ex_next_pc),
    
    .o_is_halting(ex_is_halting),

    .o_rs1_data(ex_rs1_data),
    .o_rs2_data(ex_rs2_data),

    .keep_halting(keep_halting),


    .o_imm_val(ex_imm_val),
    .o_pc_add(ex_pc_add), // 0 for rs1_data, 1 for PC
    .o_alu_src(ex_alu_src), // 0 for rs2_data, 1 for immediate
    .o_alu_opsel(ex_alu_opsel), // ALU Control Signal

    .o_dmem_read_en(ex_dmem_read_en),
    .o_dmem_write_en(ex_dmem_write_en),
    .o_funct3(ex_funct3),

    .o_reg_write_en(ex_reg_write_en), // Regiser File control
    .o_register_write_sel(ex_register_write_sel),
    .o_is_retiring(ex_is_retiring)
  );
  
  wire [31:0] ex_alu_result;
  
  execute execute (
    .pc(ex_pc),
    .imm_val(ex_imm_val),
    
    .rs1_data(ex_rs1_data),
    .rs2_data(ex_rs2_data),
    
    .pc_add(ex_pc_add), // 0 for rs1_data, 1 for PC
    .alu_src(ex_alu_src), // 0 for rs2_data, 1 for immediate
    .alu_opsel(ex_alu_opsel), // ALU Control Signal
    
    .alu_result(ex_alu_result)
  );
  
  // mem_instr is dfined earlier
  wire [31:0] mem_pc;
  wire [31:0] mem_next_pc;
  
  wire        mem_is_halting;


  wire [31:0] mem_rs1_data;
  wire [31:0] mem_rs2_data;
  
  wire [31:0] mem_alu_result;

  wire [31:0] mem_imm_val;
  wire        mem_pc_add;
  wire        mem_alu_src;
  wire [ 4:0] mem_alu_opsel;

  // mem_dmem_read_en is defined earlier
  wire        mem_dmem_write_en;
  wire [ 2:0] mem_funct3;

  // mem_reg_write_en is defined earlier
  wire [ 1:0] mem_register_write_sel;
  wire        mem_is_retiring;
  
  
  ex_mem_registers #(
    .NOP_INSTRUCTION(32'h00000013)
  ) ex_mem_registers (
    .i_clk(i_clk),

    .i_instr(ex_instr),
    .i_pc(ex_pc),
    .i_next_pc(ex_next_pc),
    
    .i_is_halting(ex_is_halting),

    .ex_flush(ex_flush),

    .i_rs1_data(ex_rs1_data),
    .i_rs2_data(ex_rs2_data),

    .i_alu_result(ex_alu_result),


    .i_dmem_read_en(ex_dmem_read_en),
    .i_dmem_write_en(ex_dmem_write_en),
    .i_funct3(ex_funct3),

    .i_imm_val(ex_imm_val),
    .i_reg_write_en(ex_reg_write_en), // Regiser File control
    .i_register_write_sel(ex_register_write_sel), 

    .i_is_retiring(ex_is_retiring),


    .o_instr(mem_instr),
    .o_pc(mem_pc),
    .o_next_pc(mem_next_pc),
    
    .o_is_halting(mem_is_halting),


    .o_rs1_data(mem_rs1_data),
    .o_rs2_data(mem_rs2_data),

    .o_alu_result(mem_alu_result),


    .o_dmem_read_en(mem_dmem_read_en),
    .o_dmem_write_en(mem_dmem_write_en),
    .o_funct3(mem_funct3),

    .o_imm_val(mem_imm_val),
    .o_reg_write_en(mem_reg_write_en), // Regiser File control
    .o_register_write_sel(mem_register_write_sel),
    
    .o_is_retiring(mem_is_retiring)
  );

  wire [31:0] mem_dmem_rdata = i_dmem_rdata;
  wire [31:0] mem_dmem_data;

  memory memory (
    .funct3(mem_funct3),
    .rs2_data(mem_rs2_data),
    .alu_result(mem_alu_result),
    .i_dmem_read_en(mem_dmem_read_en),
    .i_dmem_write_en(mem_dmem_write_en),
    .i_dmem_rdata(mem_dmem_rdata),
    
    .o_dmem_addr(o_dmem_addr),
    .o_dmem_ren(o_dmem_ren),
    .o_dmem_wen(o_dmem_wen),
    .o_dmem_wdata(o_dmem_wdata),
    .o_dmem_mask(o_dmem_mask),
    
    .dmem_data(mem_dmem_data)
  );
  
  // wb_instr  is defined earlier
  wire [31:0] wb_pc;
  // wb_next_pc is defined earlier
  
  wire        wb_is_halting;

  wire [31:0] wb_rs1_data;
  wire [31:0] wb_rs2_data;
  
  wire [31:0] wb_retire_dmem_addr;
  wire        wb_retire_dmem_ren;
  wire        wb_retire_dmem_wen;
  wire [ 3:0] wb_retire_dmem_mask;
  wire [31:0] wb_retire_dmem_wdata;
  wire [31:0] wb_retire_dmem_rdata;
  
  wire [31:0] wb_alu_result;

  wire [31:0] wb_imm_val;
  wire [31:0] wb_dmem_data;
  wire        wb_pc_add;
  wire        wb_alu_src;
  wire [ 4:0] wb_alu_opsel;
  
  // wb_reg_write_en is defined earlier
  wire [ 1:0] wb_register_write_sel;
  
  wire        wb_is_retiring;

  
  mem_wb_registers #(
    .NOP_INSTRUCTION(32'h00000013)
  ) mem_wb_registers (
    .i_clk(i_clk),
    
    .i_instr(mem_instr),
    .i_pc(mem_pc),
    .i_next_pc(mem_next_pc),

    .mem_flush(mem_flush),
    .i_is_halting(mem_is_halting),

    .i_rs1_data(mem_rs1_data),
    .i_rs2_data(mem_rs2_data),
    
    .i_retire_dmem_addr(o_dmem_addr),
    .i_retire_dmem_ren(o_dmem_ren),
    .i_retire_dmem_wen(o_dmem_wen),
    .i_retire_dmem_mask(o_dmem_mask),
    .i_retire_dmem_wdata(o_dmem_wdata),
    .i_retire_dmem_rdata(mem_dmem_rdata),

    .i_alu_result(mem_alu_result),
    .i_imm_val(mem_imm_val),
    .i_dmem_data(mem_dmem_data),
    .i_reg_write_en(mem_reg_write_en), // Regiser File control
    .i_register_write_sel(mem_register_write_sel), 
    
    .i_is_retiring(mem_is_retiring),


    .o_instr(wb_instr),
    .o_pc(wb_pc),
    .o_next_pc(wb_next_pc),
    
    .o_is_halting(wb_is_halting),

    
    .o_rs1_data(wb_rs1_data),
    .o_rs2_data(wb_rs2_data),

    .o_retire_dmem_addr(wb_retire_dmem_addr),
    .o_retire_dmem_ren(wb_retire_dmem_ren),
    .o_retire_dmem_wen(wb_retire_dmem_wen),
    .o_retire_dmem_mask(wb_retire_dmem_mask),
    .o_retire_dmem_wdata(wb_retire_dmem_wdata),
    .o_retire_dmem_rdata(wb_retire_dmem_rdata),

    .o_alu_result(wb_alu_result),
    .o_imm_val(wb_imm_val),
    .o_dmem_data(wb_dmem_data),
    .o_reg_write_en(wb_reg_write_en), // Regiser File control
    .o_register_write_sel(wb_register_write_sel),
    
    .o_is_retiring(wb_is_retiring)
  );
  
  writeback writeback (
    .register_write_sel(wb_register_write_sel),
    
    .pc(wb_pc),
    .alu_result(wb_alu_result),
    .imm_val(wb_imm_val),
    .dmem_rdata(wb_dmem_data),
    
    .writeback_data(writeback_data)
);

	///// trap logic and retire interface /////
	// None of these logical operators are permitted.
	// We will need to rewrite all of this as massive ternary statements
	// You will need to check for when a load opcode is used with an invalid funct3 FYI
	// Should probably check for valid and invalid combinations of: reg_write_en, mem_read_en, and mem_write_en
	// Should probably check for when a store opcode is used with an invalid funct3 FYI
//	wire trap_unaligned_pc = (jump | branch_taken) & (jump_target[1:0] != 2'b00);
//	wire trap_unaligned_mem = (dmem_read_en | dmem_write_en) &
//			  ((funct3 == 3'b010 & addr_align != 2'b00) |
//			  ((funct3 == 3'b001 | funct3 == 3'b101) & addr_align[0] != 1'b0));

//	// illegal instruction check 
//	wire trap_illegal_inst = (inst[1:0] != 2'b11);

	assign o_retire_valid = (~i_rst) & wb_is_retiring;
	assign o_retire_inst = wb_instr;
	assign o_retire_halt = wb_is_halting;
//  // None of these logical operators are permitted.
//	// We will need to rewrite all of this as massive ternary statements
//	assign o_retire_trap = trap_unaligned_pc | trap_unaligned_mem | trap_illegal_inst | trap_control_unit;
  assign o_retire_trap = 1'b0;
  assign o_retire_rs1_raddr = wb_instr[19:15];
	assign o_retire_rs2_raddr = wb_instr[24:20];
	assign o_retire_rs1_rdata = wb_rs1_data;
	assign o_retire_rs2_rdata = wb_rs2_data;
	assign o_retire_rd_waddr = (wb_reg_write_en) ? wb_instr[11:7] : 5'd0;
	assign o_retire_rd_wdata = (wb_reg_write_en) ? writeback_data : 32'd0;
  assign o_retire_dmem_addr = wb_retire_dmem_addr;
  assign o_retire_dmem_ren = wb_retire_dmem_ren;
  assign o_retire_dmem_wen = wb_retire_dmem_wen;
  assign o_retire_dmem_mask = wb_retire_dmem_mask;
  assign o_retire_dmem_wdata = wb_retire_dmem_wdata;
  assign o_retire_dmem_rdata = wb_retire_dmem_rdata;
	assign o_retire_pc = wb_pc;
	assign o_retire_next_pc = wb_next_pc;

	
endmodule

`default_nettype wire
