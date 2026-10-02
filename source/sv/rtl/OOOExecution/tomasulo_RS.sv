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
  input logic [FUNC_UNIT_N -1 : 0]                      fu_valid_i,

  // Empty slot
  output logic                                        issue_ready_o,
  // slot full and all source decoded

  // RS ready to be executed
  input logic                        slot_exe_hdshk_i,
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
  logic busy_s;
  logic load_s;
  logic [31:0] vj_next_s, vk_next_s;
  logic vj_avail_next_s, vk_avail_next_s;
  logic [$clog2(ROB_SIZE)-1:0] qj_next_s, qk_next_s;

  assign issue_ready_o = rst_ni && !busy_s;
  assign rs_ready_o = rst_ni && busy_s && vj_avail_s && vk_avail_s;
  assign load_s = instr_load_i && issue_ready_o;
  assign rs1_o = vj_s;
  assign rs2_o = vk_s;
  assign instr_o = instr_s;
  assign pc_o = pc_s;
  assign rd_o = destination_s;

  always_comb begin
    vj_next_s = vj_s;
    vk_next_s = vk_s;
    vj_avail_next_s = vj_avail_s;
    vk_avail_next_s = vk_avail_s;
    qj_next_s = qj_s;
    qk_next_s = qk_s;

    if (load_s) begin
      vj_next_s = register_value1_i;
      vk_next_s = register_value2_i;
      vj_avail_next_s = register1_avail_i;
      vk_avail_next_s = register2_avail_i;
      qj_next_s = rob_value1_s;
      qk_next_s = rob_value2_s;
    end

    if (busy_s || load_s) begin
      for (int fu_index = 0; fu_index < FUNC_UNIT_N; fu_index++) begin
        if (!vj_avail_next_s && fu_valid_i[fu_index] &&
            fu_dest_i[fu_index] == qj_next_s) begin
          vj_next_s = fu_value_i[fu_index];
          vj_avail_next_s = 1'b1;
        end
        if (!vk_avail_next_s && fu_valid_i[fu_index] &&
            fu_dest_i[fu_index] == qk_next_s) begin
          vk_next_s = fu_value_i[fu_index];
          vk_avail_next_s = 1'b1;
        end
      end
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      busy_s <= 1'b0;
      destination_s <= '0;
      vj_s <= '0;
      vk_s <= '0;
      vj_avail_s <= 1'b0;
      vk_avail_s <= 1'b0;
      qj_s <= '0;
      qk_s <= '0;
      instr_s <= '0;
      pc_s <= '0;
    end else begin
      if (load_s) begin
        vj_s <= vj_next_s;
        vk_s <= vk_next_s;
        vj_avail_s <= vj_avail_next_s;
        vk_avail_s <= vk_avail_next_s;
        qj_s <= qj_next_s;
        qk_s <= qk_next_s;
        busy_s <= 1'b1;
        destination_s <= rob_dest_i;
        instr_s <= instr_i;
        pc_s <= pc_i;
      end else if (slot_exe_hdshk_i) begin
        busy_s <= 1'b0;
        vj_avail_s <= 1'b0;
        vk_avail_s <= 1'b0;
      end
    end
  end

endmodule