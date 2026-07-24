// -----------------------------------------------------------------------------
// Module      : riscv_alu_logic
// File        : riscv_alu_logic.sv
// Author      : spt9pad
// Date        : 2026-06-12
// Version     : v1.0
//
// Functionality
// - Combinational bitwise logic block with operand isolation.
// - op_sel_i encoding: 2'b00=XOR, 2'b01=OR, 2'b10=AND.
// -----------------------------------------------------------------------------
module riscv_alu_logic (
  input  logic        enable_i,
  input  logic [1:0]  op_sel_i,
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

    unique case (op_sel_i)
      2'b00: result_o = op_a_iso ^ op_b_iso;
      2'b01: result_o = op_a_iso | op_b_iso;
      2'b10: result_o = op_a_iso & op_b_iso;
      default: result_o = 32'h0000_0000;
    endcase
  end

endmodule
