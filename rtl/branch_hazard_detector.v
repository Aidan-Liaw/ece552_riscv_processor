`timescale 1ns / 1ps

module branch_hazard_detector(
    input wire        i_rst,
    input wire [31:0] instr,
    input wire [ 5:0] imm_format,
    input wire id_ex_mem_read,
    input wire [4:0] id_ex_rd, 
    input wire id_ex_reg_write,
    input wire ex_mem_mem_read,
    input wire [4:0] ex_mem_rd,
    
    output reg        if_id_write_en,
    output reg        pc_write_en,
    output reg        cu_passthrough_en
);
    wire [4:0] rs1 = instr[19:15];
    wire [4:0] rs2 = instr[24:20]; 
    wire [6:0] opcode = instr[6:0];

    //this part is for cases where some registers arent used eg sw or addi or stuff
    wire rs1_rd;
    wire rs2_rd;
    //r1 used if R, I, S, B type
    assign rs1_rd = imm_format[0] | imm_format[1] | imm_format[2] | imm_format[3];
    //r2 used if R, S, B type
    assign rs2_rd = imm_format[0] | imm_format[2] | imm_format[3];
   
    //if instruction is branch or jalr
    wire is_branch = imm_format[3];  
    wire is_jalr = (opcode == 7'b1100111); 

    wire load_use_hazard;
    wire load_mem_hazard;
    wire alu_hazard;

    //standard stall after lw
    assign load_use_hazard = id_ex_mem_read & 
        (id_ex_rd != 0) & (((id_ex_rd == rs1) & rs1_rd) |
        ((id_ex_rd == rs2) & rs2_rd));

    //second stall for a branch/jalr after lw
    assign load_mem_hazard = (is_branch | is_jalr) &
        ex_mem_mem_read & (ex_mem_rd != 0) &
        (((ex_mem_rd == rs1) & rs1_rd) | ((ex_mem_rd == rs2) & rs2_rd));

    //stall if need alu result in branch or jalr
    assign alu_hazard = (is_branch | is_jalr) &
        id_ex_reg_write & !id_ex_mem_read & (id_ex_rd != 0) &
        (((id_ex_rd == rs1) & rs1_rd) | ((id_ex_rd == rs2) & rs2_rd));
    
    wire hazard;
    assign hazard = load_use_hazard | load_mem_hazard | alu_hazard;

    always @(*) begin
        case (hazard | i_rst) 
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