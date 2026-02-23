`default_nettype none

module left_shifter 
#(  parameter DATA_WIDTH = 32,
    parameter SHIFT_WIDTH = 5)
 (
    // First 32-bit input operand.
    input  wire [DATA_WIDTH - 1:0] i_op1,
    // Second 32-bit input operand.
    input  wire [SHIFT_WIDTH - 1:0] i_op2,
    // 32-bit output result. Any carry out should be ignored.
    output wire [DATA_WIDTH - 1:0] o_result
);
    
    generate
        genvar idx;
        for (idx = DATA_WIDTH - 1; idx >= 0; idx = idx - 1) begin
            // 1. i_op2 can equal 0xFFFF in theory, which would be considered negative, and cause problems, so the unsigned function stops this from being one
            // 2. signed ensures that the result is not treated as a positive number
            // 3. This HDL breaks if **anything** drives the o_result wire indirectly (such as initially assigning the wire connected to o_result in the testbench) and directly
            // Basically the code is performing a shift assignment by performing assignment for each index
            // If the index subtracted by the shift amount is valid, then its a valid shift
            // Else pad 0
            // Weird bit manipulation is an MSB check since MSB in 2's complement defines positive or negative result
            assign o_result[idx] = ((idx - i_op2[SHIFT_WIDTH - 1:0]) & ({1'b1, {(DATA_WIDTH - 1){1'b0}}})) != ({1'b1, {(DATA_WIDTH - 1){1'b0}}})
                                   ? i_op1[idx - i_op2[SHIFT_WIDTH - 1:0]]
                                   : 1'b0;
        end
    endgenerate
                  
endmodule

`default_nettype wire