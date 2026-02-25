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
    output wire [31:0] o_retire_pc,
    // the next program counter after the instruction is retired. For most
    // instructions, this is `o_retire_pc + 4`, but must be the branch or jump
    // target for *taken* branches and jumps.
    output wire [31:0] o_retire_next_pc

`ifdef RISCV_FORMAL
    ,`RVFI_OUTPUTS,
`endif
);

  ////// VARIABLES
  
	// PC wires
	reg  [31:0] pc_reg; // The PC register from the schematic
	wire [31:0] next_pc; // The wire entering the PC register in the schemayoc
	wire [31:0] pc_plus_4 = pc_reg + 32'd4; // The output wire of the adder for PC + 4
	wire [31:0] branch_target; // 1 Usage in Find. ??????

	// instruction decoding wires
	wire [31:0] inst   = i_imem_rdata;
	wire [6:0]  opcode = inst[6:0];
	wire [4:0]  rd     = inst[11:7];
	wire [2:0]  funct3 = inst[14:12];
	wire [4:0]  rs1    = inst[19:15];
	wire [4:0]  rs2    = inst[24:20];
	wire [6:0]  funct7 = inst[31:25];

	//// Control Unit wires 
	// Regiser File control
	wire reg_sign_propagation;
	wire [1:0] reg_read_size;
	wire reg_write_en;
  // Execute stage control
  wire [5:0] imm_format;
  wire pc_add; // 0 for rs1_data, 1 for PC
  wire alu_src; // 0 for rs2_data, 1 for immediate
  // Flow control
  wire branch; // 0 for non-branch instructions, 1 for branch instructions
	wire jump; // 0 for non-jump instructions, 1 for jump instructions
	wire jalr_jump;
	// Data Memory control
	wire dmem_read_en;
	wire dmem_write_en;
	// Write Register input control
	wire [3:0] dmem_mask;
	wire [1:0] register_write_sel;
	// Processor status control
	wire halt; // Active-high
	wire retire; // Active-high
	// ALU control
	wire [2:0] alu_op; // Operand setter for ALU Control module
	
	// ALU Control Signal
  wire [5:0] alu_opsel;

	// Data wires 
	wire [31:0] imm_val; // Output from Immediate Generation
	wire [31:0] rs1_data, rs2_data; // Output from RF from registers' data
	wire [31:0] writeback_data; // Data to write to Write Register
	wire [31:0] alu_in_a, alu_in_b; // ALU inputs
	wire [31:0] alu_result; // ALU result output
	wire alu_branch, alu_zero; // ALU condition outputs


  // LOGIC
  
	///// branch and next pc logic /////
  wire branch_taken;
	branch_condition_checker branch_condition_checker(branch, funct3, rs1_data, rs2_data, branch_taken);
  // IF opcode == 7'b1100111 THEN
  //    jalr jump 
  // ELSE 
  //    jal jump 
  // END IF
  // Remember that 1b shift is done in Immediate Generator, so no need to do it here.
	wire [31:0] jump_target = (opcode == 7'b1100111) ? {alu_result[31:1], 1'b0} : (pc_reg + imm_val);
	// IF jump OR branch condition valid THEN
	//   next_pc = jump_target
	// ELSE
	//   next_pc = pc_reg + 4
	// END IF
  // None of these logical operators are permitted.
	// We will need to rewrite all of this as massive ternary statements
	assign next_pc = (jump | branch_taken | jalr_jump) ? jump_target : pc_plus_4;
  // Changes PC on rising edge logic
	always @(posedge i_clk) begin
		if (i_rst) begin
			pc_reg <= RESET_ADDR;
		end else if (~halt) begin
			pc_reg <= next_pc;
		end
	end
  // Sets the I-Mem to the address whose instruction must be executed
  // ZERO CYCLE LATENCY
	assign o_imem_raddr = pc_reg;

	///// mem alignment logic /////
	wire [1:0] addr_align = alu_result[1:0];

	// mem outputs
	// In a real RV32-I, only the LSBit is 0'ed, but since we are no factoring in 
	// the C or Zc* extenstions, this is fine
	assign o_dmem_addr = {alu_result[31:2], 2'b00};
	assign o_dmem_ren = dmem_read_en;
	assign o_dmem_wen = dmem_write_en;
	
	wire [3:0]  write_dmem_mask;
  wire [3:0]  read_dmem_mask;
	wire [31:0] dmem_wdata;
	wire [31:0] mem_read_data;

  write_data_aligner write_data_aligner(addr_align, dmem_write_en, 
    funct3, rs2_data, write_dmem_mask, dmem_wdata);
    
    
  read_data_aligner read_data_aligner(addr_align, dmem_read_en,
    funct3, i_dmem_rdata, mem_read_data, read_dmem_mask);

  // If both dmem_write_en and read_dmem_mask hold true, the processor will trap
  // and execution should stop, so this should be safe
	assign o_dmem_mask = dmem_write_en == 1 ? write_dmem_mask : read_dmem_mask;
	assign o_dmem_wdata = dmem_wdata;
	
	wire trap_control_unit;
	
	///// modules /////
  control_unit ctrl (
    .opcode(opcode),
    .funct3(funct3),
    .RegSignPropagation(reg_sign_propagation),
    .RegReadSize(reg_read_size),
    .RegWriteEn(reg_write_en),
    .ImmFormat(imm_format),
    .PCAdd(pc_add),
    .Branch(branch),
    .Jump(jump),
    .JalrJump(jalr_jump),
    .MemReadEn(dmem_read_en),
    .MemWriteEn(dmem_write_en),
    .RegisterWriteSel(register_write_sel),
    .Halt(halt),
    .Trap(trap_control_unit),
    .Retire(retire),
    .ALUSrc(alu_src),
    .ALUOp(alu_op)
);

	imm_gen ig (.i_inst(inst), .i_format(imm_format), .o_immediate(imm_val));

	alu_control ac (
		.ALUOp(alu_op), .funct3(funct3), .funct7(funct7), .is_immediate(imm_format[1]), .o_opsel(alu_opsel)
	);

	// alu muxes 
	assign alu_in_a = (pc_add) ? pc_reg : rs1_data;
	assign alu_in_b = (alu_src) ? imm_val : rs2_data;

	alu arith_logic_unit (
		.i_op1(alu_in_a), .i_op2(alu_in_b), .i_opsel(alu_opsel), .result(alu_result), .zero(alu_zero)
	);

	// writeback mux 
	assign writeback_data = register_write_sel == 2'b00 ? alu_result 
	                      : register_write_sel == 2'b01 ? pc_plus_4
	                      : register_write_sel == 2'b10 ? imm_val
	                      : register_write_sel == 2'b11 ? mem_read_data //modified to read from read aligner
	                      : 32'd0;
                    
  regfile #( .BYPASS_EN(0)) rf (
    .i_clk(i_clk), .i_rst(i_rst), .i_rs1_raddr(rs1), .i_rs2_raddr(rs2), .i_rd_waddr(rd), .i_rd_wdata(writeback_data),
		.i_rd_wen(reg_write_en), .o_rs1_rdata(rs1_data), .o_rs2_rdata(rs2_data)
	);

	///// trap logic and retire interface /////
	// None of these logical operators are permitted.
	// We will need to rewrite all of this as massive ternary statements
	// You will need to check for when a load opcode is used with an invalid funct3 FYI
	// Should probably check for valid and invalid combinations of: RegWriteEn, MemReadEn, and MemWriteEn
	// Should probably check for when a store opcode is used with an invalid funct3 FYI
	wire trap_unaligned_pc = (jump | branch_taken) & (jump_target[1:0] != 2'b00);
	wire trap_unaligned_mem = (dmem_read_en | dmem_write_en) &
			  ((funct3 == 3'b010 & addr_align != 2'b00) |
			  ((funct3 == 3'b001 | funct3 == 3'b101) & addr_align[0] != 1'b0));

	// illegal instruction check 
	wire trap_illegal_inst = (inst[1:0] != 2'b11);

	assign o_retire_valid = (~i_rst);
	assign o_retire_inst = inst;
	assign o_retire_halt = halt;
  // None of these logical operators are permitted.
	// We will need to rewrite all of this as massive ternary statements
	assign o_retire_trap = trap_unaligned_pc | trap_unaligned_mem | trap_illegal_inst | trap_control_unit;
	assign o_retire_rs1_raddr = rs1;
	assign o_retire_rs2_raddr = rs2;
	assign o_retire_rs1_rdata = rs1_data;
	assign o_retire_rs2_rdata = rs2_data;
	assign o_retire_rd_waddr = (reg_write_en) ? rd : 5'd0;
	assign o_retire_rd_wdata = (reg_write_en) ? writeback_data : 32'd0;
	assign o_retire_pc = pc_reg;
	assign o_retire_next_pc = next_pc;
	
endmodule

`default_nettype wire
