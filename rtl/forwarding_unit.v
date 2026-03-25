`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 23.03.2026 17:33:20
// Design Name: 
// Module Name: forwarding_unit
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module forwarding_unit(
    input wire  [ 9:0]      if_id_rs,
    input wire              is_jump,
    input wire              is_branch,
    
    input wire  [31:0]      id_ex_instr,
    input wire  [31:0]      id_ex_pc,
    input wire  [ 9:0]      id_ex_rs,
    
    input wire  [31:0]      ex_mem_instr,
    input wire  [31:0]      ex_mem_pc,
    input wire  [ 9:0]      ex_mem_rs,
    input wire  [ 4:0]      ex_mem_rd,
    input wire  [31:0]      ex_mem_data,
    input wire              ex_mem_reg_write,
    input wire              ex_mem_mem_write,

    input wire  [31:0]      mem_wb_instr,
    input wire  [31:0]      mem_wb_pc,
    input wire  [ 4:0]      mem_wb_rd,
    input wire  [31:0]      mem_wb_data,
    input wire              mem_wb_reg_write,
    
    
    output wire [31:0] id_forward_data_rs1,
    output wire [31:0] id_forward_data_rs2,
    output reg  [ 1:0]      id_forward_sel,

    output wire [31:0] ex_forward_data_rs1,
    output wire [31:0] ex_forward_data_rs2,
    output reg  [ 1:0]      ex_forward_sel,
    
    output reg  [31:0]      mem_forward_data,
    output reg              mem_forward_sel
    );
    
    wire is_id_ex_imm = id_ex_instr[6:0] == 7'b011_0111;
    wire is_id_ex_pc_plus_4 = id_ex_instr[6:0] == 7'b110_0011;
    
    wire is_ex_mem_imm = ex_mem_instr[6:0] == 7'b011_0111;
    wire is_ex_mem_pc_plus_4 = ex_mem_instr[6:0] == 7'b110_0011;
    wire is_ex_mem_lui = ex_mem_instr[6:0] == 7'b0110111;  // LUI opcode
    wire is_ex_mem_auipc = ex_mem_instr[6:0] == 7'b0010111;
    
    wire is_mem_wb_imm = mem_wb_instr[6:0] == 7'b011_0111;
    wire is_mem_wb_pc_plus_4 = mem_wb_instr[6:0] == 7'b110_0011;
    wire is_mem_wb_lui = mem_wb_instr[6:0] == 7'b0110111;   // Add this
    wire is_mem_wb_auipc = mem_wb_instr[6:0] == 7'b0010111;

    wire [31:0] ex_mem_forward_value;
    assign ex_mem_forward_value = 
        is_ex_mem_lui ? {ex_mem_instr[31:12], 12'b0} :
        is_ex_mem_auipc ? ex_mem_pc :  
        ex_mem_data;  

    wire [31:0] mem_wb_forward_value;
    assign mem_wb_forward_value = 
        is_mem_wb_lui ? {mem_wb_instr[31:12], 12'b0} :
        is_mem_wb_auipc ? mem_wb_pc :
        mem_wb_data;

    
    // Selector line logic
    always @(*) begin
      id_forward_sel[0] <= (is_jump | is_branch) 
                            & (if_id_rs[4:0] != 5'd0)
                            & ((if_id_rs[4:0] == ex_mem_rd) | (if_id_rs[4:0] == mem_wb_rd));
      id_forward_sel[1] <= is_jump 
                            & (if_id_rs[9:5] != 5'd0)
                            & ((if_id_rs[9:5] == ex_mem_rd) | (if_id_rs[9:5] == mem_wb_rd));       
      
      ex_forward_sel[0] <= (ex_mem_reg_write | mem_wb_reg_write)
                            & (id_ex_rs[4:0] != 5'd0)
                            & ((id_ex_rs[4:0] == ex_mem_rd) | (id_ex_rs[4:0] == mem_wb_rd));                           
      ex_forward_sel[1] <= (ex_mem_reg_write | mem_wb_reg_write)
                            & (id_ex_rs[9:5] != 5'd0)
                            & ((id_ex_rs[9:5] == ex_mem_rd) | (id_ex_rs[9:5] == mem_wb_rd));
      
      // For load to store
      mem_forward_sel <= (ex_mem_mem_write == mem_wb_reg_write)
                         & (ex_mem_rd == 5'd0)
                         & (ex_mem_rs[9:5] == mem_wb_rd);
    end
    
    // Forwarding to ID for jalr or branch instructions
    // always @(*) begin
    //   case ({ex_mem_reg_write, is_ex_mem_imm, is_ex_mem_pc_plus_4, is_mem_wb_imm, is_mem_wb_pc_plus_4})
    //     5'b1_00_00: id_forward_data <= ex_mem_data;
    //     5'b1_10_00: id_forward_data <= {ex_mem_instr[31:12], 12'b0};
    //     5'b1_01_00: id_forward_data <= ex_mem_pc + 4;
    //     5'b0_00_00: id_forward_data <= mem_wb_data;
    //     5'b0_00_10: id_forward_data <= {mem_wb_instr[31:12], 12'b0};
    //     5'b0_00_01: id_forward_data <= mem_wb_pc + 4;
    //     default: id_forward_data <= 32'd0;
    //   endcase
    // end
    assign id_forward_data_rs1 =
    (ex_mem_reg_write && (if_id_rs[4:0] == ex_mem_rd) && (if_id_rs[4:0] != 5'd0)) ? ex_mem_forward_value :
    (mem_wb_reg_write && (if_id_rs[4:0] == mem_wb_rd) && (if_id_rs[4:0] != 5'd0)) ? mem_wb_forward_value :
    32'd0;

    assign id_forward_data_rs2 =
        (ex_mem_reg_write && (if_id_rs[9:5] == ex_mem_rd) && (if_id_rs[9:5] != 5'd0)) ? ex_mem_forward_value :
        (mem_wb_reg_write && (if_id_rs[9:5] == mem_wb_rd) && (if_id_rs[9:5] != 5'd0)) ? mem_wb_forward_value :
        32'd0;



    // Forwarding to EX
    // assign ex_forward_data =
    //     (ex_mem_reg_write & ~is_ex_mem_imm & ~is_ex_mem_pc_plus_4) ? ex_mem_data :
    //     (ex_mem_reg_write &  is_ex_mem_imm)? {ex_mem_instr[31:12], 12'b0} :
    //     (ex_mem_reg_write &  is_ex_mem_pc_plus_4)? ex_mem_pc + 4 :
    //     (mem_wb_reg_write & ~is_mem_wb_imm & ~is_mem_wb_pc_plus_4)? mem_wb_data :
    //     (mem_wb_reg_write &  is_mem_wb_imm)? {mem_wb_instr[31:12], 12'b0} :
    //     (mem_wb_reg_write &  is_mem_wb_pc_plus_4)? mem_wb_pc + 4 :
    //     32'd0;
    assign ex_forward_data_rs1 =
    (ex_mem_reg_write && (id_ex_rs[4:0] == ex_mem_rd) && (id_ex_rs[4:0] != 5'd0)) ? ex_mem_forward_value :
    (mem_wb_reg_write && (id_ex_rs[4:0] == mem_wb_rd) && (id_ex_rs[4:0] != 5'd0)) ? mem_wb_forward_value :
    32'd0;

    assign ex_forward_data_rs2 =
        (ex_mem_reg_write && (id_ex_rs[9:5] == ex_mem_rd) && (id_ex_rs[9:5] != 5'd0)) ? ex_mem_forward_value :
        (mem_wb_reg_write && (id_ex_rs[9:5] == mem_wb_rd) && (id_ex_rs[9:5] != 5'd0)) ? mem_wb_forward_value :
        32'd0;
    
    
    // always @(*) begin
    //   case ({ex_mem_reg_write, is_ex_mem_imm, is_ex_mem_pc_plus_4, is_mem_wb_imm, is_mem_wb_pc_plus_4})
    //     5'b1_00_00: ex_forward_data <= ex_mem_data;
    //     5'b1_10_00: ex_forward_data <= {ex_mem_instr[31:12], 12'b0};
    //     5'b1_01_00: ex_forward_data <= ex_mem_pc + 4;
    //     5'b0_00_00: ex_forward_data <= mem_wb_data;
    //     5'b0_00_10: ex_forward_data <= {mem_wb_instr[31:12], 12'b0};
    //     5'b0_00_01: ex_forward_data <= mem_wb_pc + 4;
    //     default: ex_forward_data <= 32'd0;
    //   endcase
    // end
    
    // Forwarding to MEM
    // Note, you probably want to check whether imm and pc + 4 forwarding is valid
    always @(*) begin
      case ({is_mem_wb_imm, is_mem_wb_pc_plus_4})
        2'b00: mem_forward_data <= mem_wb_data;
        2'b10: mem_forward_data <= {mem_wb_instr[31:12], 12'b0};
        2'b01: mem_forward_data <= mem_wb_pc + 4;
        default: mem_forward_data <= 32'd0;
      endcase
    end
endmodule
