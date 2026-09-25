// -----------------------------------------------------------------------------
// Module      : riscv_alu_compare
// File        : riscv_alu_compare.sv
// Author      : spt9pad
// Date        : 2026-06-12
// Version     : v1.0
//
// Functionality
// - Combinational comparison block with operand isolation.
// - Supports signed/unsigned less-than compare.
// -----------------------------------------------------------------------------
module riscv_alu_compare (
  input  logic        enable_i,
  input  logic        unsigned_i,
  input  logic [31:0] op_a_i,
  input  logic [31:0] op_b_i,
  output logic [31:0] result_o
);

  logic [31:0] op_a_iso;
  logic [31:0] op_b_iso;
  logic        less_than;

  // Operand isolation to reduce unnecessary internal toggling.
  always_comb begin
    op_a_iso = enable_i ? op_a_i : 32'h0000_0000;
    op_b_iso = enable_i ? op_b_i : 32'h0000_0000;

    if (unsigned_i) begin
      less_than = (op_a_iso < op_b_iso);
    end else begin
      less_than = ($signed(op_a_iso) < $signed(op_b_iso));
    end

    result_o = less_than ? 32'd1 : 32'd0;
  end

endmodule
