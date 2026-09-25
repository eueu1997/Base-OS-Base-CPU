// Module      : tomasulo_RS
// File        : tomasulo_RS.sv
// Author      : spt9pad
// Date        : 2026-09-25
// Version     : v1.1
// Functionality: Holds operands and dispatches aligned instruction/PC metadata.
module tomasulo_RS # (
  parameter int ROB_SIZE = 8,
  parameter int FUNC_UNIT_N = 8
)(
  input logic                        clk_i,
  input logic                        rst_ni,
  input logic [31:0]                 register_value1_i,
  input logic [31:0]                 register_value2_i,
  input logic                        register1_avail_i,
  input logic                        register2_avail_i,
  input logic [$clog2(ROB_SIZE)-1:0] rob_value1_s,
  input logic [$clog2(ROB_SIZE)-1:0] rob_value2_s,
  input logic                        instr_load_i,
  input logic [31:0]                  instr_i,
  input logic [31:0]                  pc_i,
  input logic [$clog2(ROB_SIZE)-1:0] rob_dest_i,
  // Data bus input
  input logic [FUNC_UNIT_N -1 : 0][$clog2(ROB_SIZE)-1:0] fu_dest_i,
  input logic [FUNC_UNIT_N -1 : 0][31:0]                 fu_value_i,

  // RS ready to be executed
  output logic                       rs_ready_o,
  output logic [31:0]                rs1_o,
  output logic [31:0]                rs2_o,
  output logic [31:0]                instr_o,
  output logic [31:0]                pc_o,
  output logic [$clog2(ROB_SIZE)-1:0]rd_o
);

  logic [$clog2(ROB_SIZE)-1:0] destination_s;
  logic [31:0]                 vj_s,vk_s;
  logic                        vj_avail_s,vk_avail_s;
  logic [$clog2(ROB_SIZE)-1:0] qj_s,qk_s;
  logic [31:0] instr_s;
  logic [31:0] pc_s;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      instr_s <= '0;
      pc_s <= '0;
      instr_o <= '0;
      pc_o <= '0;
    end else begin
      if (instr_load_i) begin
        instr_s <= instr_i;
        pc_s <= pc_i;
      end
      if (vj_avail_s && vk_avail_s) begin
        instr_o <= instr_s;
        pc_o <= pc_s;
      end
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni)begin

    if(instr_load_i)begin
      if(register1_avail_i) begin
        vj_s <= register_value1_i;
        vj_avail_s <= 1'b1;
      end else begin
        qj_s <= rob_value1_s;
        vj_avail_s <= 1'b0;
      end
      if(register2_avail_i) begin
        vk_s <= register_value2_i;
        vk_avail_s <= 1'b1;
      end else begin
        qk_s <= rob_value2_s;
        vk_avail_s <= 1'b0;
      end
    destination_s <= rob_dest_i;
    end

    if (!vj_avail_s)begin
      if(fu_dest_i == qj_s)begin
        vj_s <= fu_value_i;
        vj_avail_s <= 1'b1;
      end
    end
    if (!vk_avail_s)begin
      if(fu_dest_i == qk_s)begin
        vk_s <= fu_value_i;
        vk_avail_s <= 1'b1;
      end
    end

    if (vj_avail_s && vk_avail_s)begin
      rs_ready_o <= 1'b1;
      rs1_o <= vj_s;
      rs2_o <= vk_s;
      rd_o <= destination_s;
    end else
      rs_ready_o <= 1'b0;
  end

endmodule