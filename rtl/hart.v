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
    // Fill in your implementation here.

	// PC wires
	reg [31:0]] pc_reg;
	wire [31:0] next_pc;
	wire [31:0] pc_plus_4 = pc_reg + 32'd4;
	wire [31:0] branch_target;

	// instruction decoding wires
	wire [31:0] inst = i_mem_rdata;
	wire [6:0] opcode = inst[6:0];
	wire [4:0] rd = inst[11:7];
	wire [2:0] func3 = inst[14:12];
	wire [4:0] rs1 = inst[19:15];
	wire [4:0] rs2 = inst[24:20];
	wire [6:0] func7 = inst[31:25];

	// control unit wires 
	wire alu_src, mem_to_reg, reg_write, mem_read, mem_write;
	wire branch, jump, halt_sig;
	wire [1:0] alu_op_type;
	wire [3:0] alu_cmd;

	// data wires 
	wire [31:0] imm_val;
	wire [31:0] rs1_data, rs2_data, writeback_data;
	wire [31:0] alu_in_a, alu_in_b, alu_result;
	wire alu_zero;

	///// branch and next pc logic /////
	reg branch_taken;
	always @(*) begin
		if (branch) begin
			case(func3)
				3'b000: 
					branch_taken = (rs1_data == rs2_data);  // beq
				3'b001: 
					branch_taken = (rs1_data != rs2_data);  // bne
				3'b100: 
					branch_taken = ($signed(rs1_data) < $signed(rs2_data));  // blt
				3'b101: 
					branch_taken = ($signed(rs1_data) >= $signed(rs2_data));  // bge
				3'b110: 
					branch_taken = (rs1_data < rs2_data);  // bltu
				3'b111: 
					branch_taken = (rs1_data >= rs2_data);  // bgeu
				default: 
					branch_taken = 1'b0;
			endcase
		end else begin
			branch_taken = 1'b0;
		end
	end

	wire [31:0] jump_target = (opcode == 7'b1100111) ? {alu_result[31:1], 1'b0} : (pc_reg + imm_val);
	wire [31:0] next_pc = (jump || branch_taken) ? jump_target : pc_plus_4;

	always @(posedge i_clk) begin
		if (i_rst) begin
			pc_reg <= RESET_ADDR;
		end else if (!halt_sig) begin
			pc_reg <= next_pc;
		end
	end

	assign o_imem_raddr = pc_reg;

	///// mem alignment logic /////
	wire [1:0] addr_align = alu_result[1:0]

	// mem outputs
	assign o_dmem_addr = {alu_result[31:2], 2'b00};
	assign o_dmem_ren = mem_read;
	assign o_dmem_wen = mem_write;

	reg [3:0] dmem_mask;
	reg [31:0] dmem_wdata;

	// write data alignment 
	always @(*) begin
		dmem_mask = 4'b0000;
		dmem_wdata = 32'b0;

		if (mem_write) begin
			case(func3)
				//sb
				3'b000: begin
					dmem_mask = 4'b0001 << addr_align;
					dmem_wdata = {4{rs2_data[7:0]}};
				end

				// sh
				3'b001: begin
					dmem_mask = 4'b0011 << {addr_a;ign[1], 1'b0};
					dmem_wdata = {2{rs2_data[15:0]}};
				end

				// sw 
				3'b010: begin
					dmem_mask = 4'b1111;
					dmem_wdata = rs2_data;
				end
			endcase

		end else if (mem_read) begin
			case (func3)
				// lb and lbu
				3'b000, 3'b100:
					dmem_mask = 4'b0001 << addr_align;
				// lh and lhu
				3'b001, 3'b101: 
					dmem_mask = 4'b0011 << {addr_align[1], 1'b0};
				// lw
				3'b010:
					dmem_mask = 4'b1111;
			endcase
		end
	end

	assign o_dmem_mask = dmem_mask;
	assign o_dmem_wdata = dmem_wdata;

	// read data alignment 
	reg [31:0] mem_read_data;
	wire [31:0] shifted_rdata = i_mem_rdata >> {addr_align, 3'b000};

	always @(*) begin
		case (func3)
			// lb
			3'b000:
				mem_read_data = {{24{shifted_rdata[7]}}, shifted_rdata[7:0]};
			// lbu
			3'b100:
				mem_read_data = {24'b0, sifted_rdata[7:0]};
			// lh
			3'b001: 
				mem_read_data = {{16{shifted_rdata[15]}}, shifted_rdata[15:0]};
			// lhu
			3'b101:
				mem_read_data = {16'b0, shifted_rdata[15:0]};
			// lw
			default:
				mem_read_data = shifted_rdata;
		endcase
	end

	///// modules /////
	control_unit ctrl (
		.opcode(opcode), .alu_src(alu_src), .mem_to_reg(mem_to_reg), .reg_write(reg_write), .mem_read(mem_read), 
		.mem_write(mem_write), .branch(branch), .jump(jump), .halt(halt_sig), .alu_op_type(alu_op_type)
	);

	imm_gen ig (.inst(inst), .imm(imm_val));

	regfile #( .BYPASS_EN(0) rf (
		.clk(i_clk), .rst(i_rst), .read_reg1(rs1), .read_reg2(rs2), .write_reg(rd), .write_data(writeback_data),
		.write_en(reg_write), .read_data1(rs1_data), .read_data2(rs2_data)
	);

	alu_control ac (
		.alu_op_type(alu_op_type), .func3(func3), .bit30(inst[30]), .alu_cmd(alu_cmd)
	);

	// alu muxes 
	assign alu_in_a = (opcode == 7'b0010111) ? pc_reg : rs1_data;
	assign alu_in_b = (alu_src) ? imm_val : rs2_data;

	alu arith_logic_unit (
		.in_a(alu_in_a), .in_b(alu_in_b), .alu_op(alu_cmd), .result(alu_result), .zero(alu_zero)
	);

	// writeback mux 
	assign writeback_data = (jump) ? pc_plus_4 :
				  (mem_to_reg) ? mem_read_data :
				  (opcode == 7'b0110111) ? imm_val :
				  alu_result;

	///// trap logic and retire interface /////
	wire trap_unaligned_pc = (jump || branch_taken) && (jump_target[1:0] != 2'b00);
	wire trap_unaligned_mem = (mem_read || em_write) &&
			  ((func3 == 3'b010 && addr_align != 2'b00) ||
			   ((func3 == 3'b001 || func3 == 3'b101) && addr_align[0] != 1'b0));

	// illegal instruction check 
	wire trap_illegal_inst = (inst[1:0] != 2'b11);

	assign o_retire_valid = !i_rst && !halt_sig;
	assign o_retire_inst = inst;
	assign o_retire_halt = halt_sig;
	assign o_retire_trap = trap_unaligned_pc || trap_unaligned_mem || trap_illegal_inst;
	assign o_retire_rs1_raddr = rs1;
	assign o_retire_rs2_raddr = rs2;
	assign o_retire_rs1_rdata = rs1_data;
	assign o_retire_rs2_rdata = rs2_data;
	assign o_retire_rd_waddr = (reg_write) ? rd : 5'd0;
	assign o_retire_rd_wdata = (reg_write) ? writeback_data : 32'd0;
	assign o_retire_pc = pc_reg;
	assign o_retire_next_pc = next_pc;
	
endmodule

`default_nettype wire
