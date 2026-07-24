// -----------------------------------------------------------------------------
// Module      : riscv_top
// File        : riscv_top.sv
// Author      : spt9pad
// Date        : 2026-06-12
// Version     : v1.0
//
// Functionality
// - Top-level wrapper that instantiates the RISC-V core and a dedicated
//   instruction memory module.
// - Bridges the core fetch interface (req/addr/rdata/rvalid) to IMEM.
//
// Integration Notes
// - This is a bring-up oriented top for early simulation/debug.
// - For ASIC integration, instruction memory is typically replaced by
//   ROM/cache/subsystem interfaces.
// -----------------------------------------------------------------------------
module riscv_top #(
  parameter int IMEM_WORDS = 1024,
  parameter string IMEM_HEX_FILE = ""
) (
  input  logic        clk_i,
  input  logic        rst_ni,
  output logic        illegal_instr_o
);

  // Core instance.
  riscv #(
    .IMEM_WORDS    (IMEM_WORDS),
    .IMEM_HEX_FILE (IMEM_HEX_FILE)
  ) u_riscv (
    .clk_i          (clk_i),
    .rst_ni         (rst_ni),
    .illegal_instr_o(illegal_instr_o)
  );

endmodule
