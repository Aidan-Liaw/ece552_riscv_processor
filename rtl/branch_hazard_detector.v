`timescale 1ns / 1ps

module branch_hazard_detector(
    input wire [31:0] instr,
    input wire [ 5:0] imm_format,
    input wire [ 4:0] id_ex_rd,
    input wire        id_ex_reg_write,
    input wire [ 4:0] ex_mem_rd,
    input wire        ex_mem_reg_write,
    input wire [ 4:0] mem_wb_rd,
    input wire        mem_wb_reg_write,

    output reg        if_id_write_en,
    output reg        pc_write_en,
    output reg        cu_passthrough_en
);
    wire [4:0] rs1 = instr[19:15];
    wire [4:0] rs2 = instr[24:20]; 

    //this part is for cases where some registers arent used eg sw or addi or stuff
    wire rs1_rd;
    wire rs2_rd;
    //r1 used if R, I, S, B type
    assign rs1_rd = imm_format[0] | imm_format[1] | imm_format[2] | imm_format[3];
    //r2 used if R, S, B type
    assign rs2_rd = imm_format[0] | imm_format[2] | imm_format[3];

    wire hazard;
    //if id/ex.writereg = if/id.regrs1 or rs2
    assign hazard = ((id_ex_reg_write & (id_ex_rd != 5'b00000) & (((id_ex_rd == rs1) & rs1_rd) | ((id_ex_rd == rs2) & rs2_rd)))
                    //if ex/mem.writereg = if/id.regrs1 or rs2
                    | (ex_mem_reg_write & (ex_mem_rd != 5'b00000) & (((ex_mem_rd == rs1) & rs1_rd) | ((ex_mem_rd == rs2) & rs2_rd)))
                    //if mem/wb.writereg = if/id.regrs1 or rs2
                    | (mem_wb_reg_write & (mem_wb_rd != 5'b00000) & (((mem_wb_rd == rs1) & rs1_rd) | ((mem_wb_rd == rs2) & rs2_rd))));

    always @(*) begin
        case (hazard) 
            1'b1: begin
                pc_write_en = 0;
                if_id_write_en = 0;
                cu_passthrough_en = 0;
            end
            default: begin
                pc_write_en = 1;
                if_id_write_en = 1;
                cu_passthrough_en = 1;
            end
        endcase
    end

endmodule