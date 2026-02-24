`timescale 1ns / 1ps

`default_nettype none

// The immediate generator is responsible for decoding the 32-bit sign-extended
// immediate from the incoming instruction word. It is a purely combinational
// block that is expected to be embedded in the instruction decoder.
module imm_gen (
    // Input instruction word. This is used to extract the relevant immediate
    // bits and assemble them into the final immediate.
    input  wire [31:0] i_inst,
    // Instruction format, determined by the instruction decoder based on the
    // opcode. This is one-hot encoded according to the following format:
    // [0] R-type
    // [1] I-type
    // [2] S-type
    // [3] B-type
    // [4] U-type
    // [5] J-type
    input  wire [ 5:0] i_format,
    // Output 32-bit sign-extended immediate.
    // NOTE: Because the R-type format does not have an immediate, the output
    // immediate can be treated as a don't-care under this case. It is included
    // for completeness.
    output wire [31:0] o_immediate
);
    // The immediate generation logic below has at least one bug. Fix the
    // provided implementation below to generate the correct immediate values
    // for all instruction formats. You are encouraged to make a testbench and
    // look through waveforms as you do this.
    wire [31:0] imm_r = {{32{1'bx}}}; // 32 = 32
    wire [31:0] imm_i = {{21{i_inst[31]}}, i_inst[30:20]}; // 21 + 11 = 32
    wire [31:0] imm_s = {{21{i_inst[31]}}, i_inst[30:25], i_inst[11:7]}; // 21 + 6 + 5 = 32
    wire [31:0] imm_b = {{20{i_inst[31]}}, i_inst[7], i_inst[30:25], i_inst[11:8], 1'b0}; // 20 + 1 + 6 + 4 + 1 = 32
    wire [31:0] imm_u = {i_inst[31:12], 12'b0}; // 20 + 12 = 32
    wire [31:0] imm_j = {{12{i_inst[31]}}, i_inst[19:12], i_inst[20], i_inst[30:25], i_inst[24:21], 1'b0}; // 12 + 8 + 1 + 6 + 4 + 1 = 32

    assign o_immediate = i_format[0] ? imm_r :
                         i_format[1] ? imm_i :
                         i_format[2] ? imm_s :
                         i_format[3] ? imm_b :
                         i_format[4] ? imm_u :
                         i_format[5] ? imm_j :
                         32'b0;
endmodule

`default_nettype wire