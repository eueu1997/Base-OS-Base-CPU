// Module      : riscv_fu_jump
// File        : riscv_fu_jump.sv
// Author      : GitHub Copilot
// Date        : 2026-09-25
// Version     : v1.0
// Functionality: Inactive placeholder for jump FU slot 6; never completes.
module riscv_fu_jump #(
  parameter int ROB_TAG_WIDTH = 3
)(
  input logic enable_i,
  input logic [31:0] instr_i,
  input logic [31:0] pc_i,
  input logic [31:0] op_a_i,
  input logic [31:0] op_b_i,
  input logic [ROB_TAG_WIDTH-1:0] dest_i,
  output logic [31:0] result_o,
  output logic [ROB_TAG_WIDTH-1:0] dest_o,
  output logic valid_o
);
  assign result_o = '0;
  assign dest_o = dest_i;
  assign valid_o = 1'b0;
endmodule