// Module      : tomasulo_RS_top
// File        : tomasulo_RS_top.sv
// Author      : spt9pad
// Date        : 2026-09-25
// Version     : v1.1
// Functionality: Holds operands and dispatches aligned instruction/PC metadata.
module tomasulo_RS_top # (
  parameter int ROB_SIZE = 8,
  parameter int FUNC_UNIT_N = 8,
  parameter int RS_SIZE = 8
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
  input logic [FUNC_UNIT_N -1 : 0]                       fu_valid_i,

  output logic                                           full_rs_o,
  output logic                                           empty_rs_o,

  // RS ready to be executed
  input logic                                            fu_en_i,
  output logic [31:0]                                    rs1_o,
  output logic [31:0]                                    rs2_o,
  output logic [31:0]                                    instr_o,
  output logic [31:0]                                    pc_o,
  output logic [$clog2(ROB_SIZE)-1:0]                    rd_o,
  output logic                                           fu_exe_en_o
);

  // RS enable signals for each slot
  logic [RS_SIZE-1:0] slot_enable_s;
  // RS slot availability signals (ready to accept new instruction)
  logic [RS_SIZE-1:0] slot_ready_s;
  // Slot ready to execute signals for each slot
  logic [RS_SIZE-1:0] slot_ready_exe_s, rs_enable_exe_s;
  logic [RS_SIZE-1:0] slot_exe_hdshk_s;
  logic [31:0]                rs1_s[RS_SIZE-1:0];
  logic [31:0]                rs2_s[RS_SIZE-1:0];
  logic [31:0]                instr_s[RS_SIZE-1:0];
  logic [31:0]                pc_s[RS_SIZE-1:0];
  logic [$clog2(ROB_SIZE)-1:0]rd_s[RS_SIZE-1:0];

  // If all slot are not ready to be loaded, means RS is full
  assign full_rs_o = ~|slot_ready_s;
  // If all slot are ready to be loaded, means RS is empty
  assign empty_rs_o = &slot_ready_s;

  // Combinatorial logic to enable the right RS slot based on availability and instruction load
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      slot_enable_s <= '0;
    end else begin
      slot_enable_s = '0;
      for (int slot_index = 0; slot_index < RS_SIZE; slot_index++) begin
        if (slot_ready_s[slot_index] && instr_load_i) begin
          slot_enable_s[slot_index] = 1'b1;
          break;
        end
      end
    end
  end

  // Output arbitrer
  always_comb begin
    rs_enable_exe_s = '0;
    for (int slot_index = 0; slot_index < RS_SIZE; slot_index++) begin
      if (slot_ready_exe_s[slot_index] && fu_en_i) begin
        rs_enable_exe_s[slot_index] = 1'b1;
        break;
      end
    end
  end

  // Slot output mux
  always_comb begin
    rs1_o = '0;
    rs2_o = '0;
    instr_o = '0;
    pc_o = '0;
    rd_o = '0;
    fu_exe_en_o = 1'b0;
    slot_exe_hdshk_s = '0;
    for (int slot_index = 0; slot_index < RS_SIZE; slot_index++) begin
      if (rs_enable_exe_s[slot_index] && fu_en_i) begin
        rs1_o = rs1_s[slot_index];
        rs2_o = rs2_s[slot_index];
        instr_o = instr_s[slot_index];
        pc_o = pc_s[slot_index];
        rd_o = rd_s[slot_index];
        fu_exe_en_o = 1'b1;
        slot_exe_hdshk_s[slot_index] = 1'b1;
      end
    end
  end
  generate
      for(genvar rs_index = 0; rs_index < RS_SIZE; rs_index++)begin : gen_rs
        tomasulo_RS #(
          .ROB_SIZE(ROB_SIZE),
          .FUNC_UNIT_N(FUNC_UNIT_N)
        ) u_tomasulo_RS (
          .clk_i(clk_i),
          .rst_ni(rst_ni),
          // slot available for loading
          .issue_ready_o(slot_ready_s[rs_index]),
          // Signals from RAT
          .register_value1_i(register_value1_i),
          .register_value2_i(register_value2_i),
          .register1_avail_i(register1_avail_i),
          .register2_avail_i(register2_avail_i),
          .rob_value1_s(rob_value1_s),
          .rob_value2_s(rob_value2_s),
          // Instruction and PC
          .instr_i(instr_i),
          .pc_i(pc_i),
          // Destination ROB entry
          .rob_dest_i(rob_dest_i),
          // New instruction load in slot
          .instr_load_i(slot_enable_s[rs_index]),
          // FU output data bus
          .fu_dest_i(fu_dest_i),
          .fu_value_i(fu_value_i),
          .fu_valid_i(fu_valid_i),
          // RS ready to be executed
          .rs_ready_o(slot_ready_exe_s[rs_index]),
          .rs1_o(rs1_s[rs_index]),
          .rs2_o(rs2_s[rs_index]),
          .instr_o(instr_s[rs_index]),
          .pc_o(pc_s[rs_index]),
          .rd_o(rd_s[rs_index]),
          .slot_exe_hdshk_i(slot_exe_hdshk_s[rs_index])
        );
      end
  endgenerate
endmodule