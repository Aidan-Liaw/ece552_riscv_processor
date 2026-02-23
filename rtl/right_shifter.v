`default_nettype none

module right_shifter
#(  parameter DATA_WIDTH = 32,
    parameter SHIFT_WIDTH = 5)
 (
    // When asserted, right shifts should be treated as arithmetic instead of
    // logical. This is only used for `i_opsel == 3'b101` (shift right).
    input  wire        i_arith,
    // First 32-bit input operand.
    input  wire [DATA_WIDTH - 1:0] i_op1,
    // Second 32-bit input operand.
    input  wire [SHIFT_WIDTH - 1:0] i_op2,
    // 32-bit output result. Any carry out should be ignored.
    output wire [DATA_WIDTH - 1:0] o_result
);
    genvar idx;
    
    generate
        for (idx = 0; idx < DATA_WIDTH; idx = idx + 1) begin
            // Basically the code is performing a shift assignment by performing assignment for each index
            // If the index added by the shift amount is valid, then its a valid shift
            // Else pad 0 or the MSBit depending on whether the shift is logical or arithmetic
            // Note the weird 1'b0 appends to ensure that the value is unsigned when the comparison takes palce
            // Code was originally tested without the [4:0] slice, so weird append may no longer be required
            assign o_result[idx] = {1'b0, i_op2[SHIFT_WIDTH - 1:0]} + idx < DATA_WIDTH ? i_op1[i_op2[SHIFT_WIDTH - 1:0] + idx] :
                                   i_arith == 1'b1                                     ? i_op1[DATA_WIDTH - 1]                 :
                                   1'b0;
        end
    endgenerate                  
endmodule

`default_nettype wire