// -----------------------------------------------------------------------------
// Module      : riscv_alu_addsub
// File        : riscv_alu_addsub.sv
// Author      : spt9pad
// Date        : 2026-06-12
// Version     : v1.0
//
// Functionality
// - Combinational add/sub block with operand isolation.
// - When enable_i is low, isolated operands are forced to zero.
// -----------------------------------------------------------------------------
module riscv_alu_addsub (
  input  logic        enable_i,
  input  logic        sub_i,
  input  logic [31:0] op_a_i,
  input  logic [31:0] op_b_i,
  output logic [31:0] result_o
);

  logic [31:0] op_a_iso;
  logic [31:0] op_b_iso;

  // Operand isolation to reduce unnecessary internal toggling.
  always_comb begin
    op_a_iso = enable_i ? op_a_i : 32'h0000_0000;
    op_b_iso = enable_i ? op_b_i : 32'h0000_0000;

    if (sub_i) begin
      result_o = op_a_iso - op_b_iso;
    end else begin
      result_o = op_a_iso + op_b_iso;
    end
  end

endmodule
