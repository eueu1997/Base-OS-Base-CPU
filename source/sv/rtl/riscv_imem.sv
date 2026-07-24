// -----------------------------------------------------------------------------
// Module      : riscv_imem
// File        : riscv_imem.sv
// Author      : spt9pad
// Date        : 2026-06-12
// Version     : v1.0
//
// Functionality
// - Instruction memory model for early RISC-V core bring-up.
// - Supports optional preload from HEX file via $readmemh.
// - Returns NOP on misaligned or out-of-range fetch addresses.
//
// Integration Notes
// - Combinational response, modeled as zero-wait-state.
// - Intended for simulation/prototyping; replace with ROM/cache in ASIC flow.
// -----------------------------------------------------------------------------
module riscv_imem #(
  parameter int IMEM_WORDS = 1024,
  parameter string IMEM_HEX_FILE = ""
) (
  input  logic        req_i,
  input  logic [31:0] addr_i,
  output logic [31:0] rdata_o,
  output logic        rvalid_o
);

  // Instruction memory storage.
  logic [31:0] imem [0:IMEM_WORDS-1];
  integer i;

  // Detect legal word-aligned accesses within IMEM range.
  logic imem_addr_aligned;
  logic imem_addr_in_range;

  assign imem_addr_aligned = (addr_i[1:0] == 2'b00);
  assign imem_addr_in_range = (addr_i[31:2] < IMEM_WORDS);

  // Instruction memory response model.
  // For now, response is modeled as always-ready and zero-wait-state.
  always_comb begin
    rvalid_o = req_i;

    if (!imem_addr_aligned) begin
      // Return NOP on misaligned fetch addresses.
      rdata_o = 32'h0000_0013;
    end else if (imem_addr_in_range) begin
      rdata_o = imem[addr_i[31:2]];
    end else begin
      // Return NOP on out-of-range fetch addresses.
      rdata_o = 32'h0000_0013;
    end
  end

  // Initialize instruction memory contents.
  initial begin
    for (i = 0; i < IMEM_WORDS; i = i + 1) begin
      // Default content is NOP (ADDI x0, x0, 0).
      imem[i] = 32'h0000_0013;
    end

    if (IMEM_HEX_FILE != "") begin
      $readmemh(IMEM_HEX_FILE, imem);
    end
  end

endmodule
