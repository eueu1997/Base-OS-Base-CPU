// -----------------------------------------------------------------------------
// Module      : riscv_alu_shift
// File        : riscv_alu_shift.sv
// Author      : spt9pad
// Date        : 2026-06-12
// Version     : v1.0
//
// Functionality
// - Combinational shift block with operand isolation.
// - Supports SLL, SRL, SRA using left_i/arithmetic_i controls.
// -----------------------------------------------------------------------------
module riscv_alu_shift (
  input  logic        enable_i,
  input  logic        left_i,
  input  logic        arithmetic_i,
  input  logic [31:0] op_a_i,
  input  logic [4:0]  shamt_i,
  output logic [31:0] result_o
);

  logic [31:0] op_a_iso;
  logic [4:0]  shamt_iso;

  // Operand isolation to reduce unnecessary internal toggling.
  always_comb begin
    op_a_iso  = enable_i ? op_a_i : 32'h0000_0000;
    shamt_iso = enable_i ? shamt_i : 5'd0;

    if (left_i) begin
      result_o = op_a_iso << shamt_iso;
    end else if (arithmetic_i) begin
      result_o = $signed(op_a_iso) >>> shamt_iso;
    end else begin
      result_o = op_a_iso >> shamt_iso;
    end
  end

endmodule
