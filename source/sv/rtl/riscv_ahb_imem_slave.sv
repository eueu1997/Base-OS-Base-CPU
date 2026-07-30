// -----------------------------------------------------------------------------
// Module      : riscv_ahb_imem_slave
// File        : riscv_ahb_imem_slave.sv
// Author      : spt9pad
// Date        : 2026-07-29
// Version     : v1.0
//
// Functionality
// - AHB-Lite slave wrapper around riscv_imem, acting as the bus-side
//   instruction memory reachable by the core's read-only AHB-Lite master
//   port (riscv_icache refill path).
// - Read-only: HWRITE is expected low (instruction fetch never writes);
//   write transfers are not supported and are ignored.
// - Zero-wait-state slave: HREADY is always driven high, because the
//   underlying riscv_imem model is a single-cycle combinational read.
// - HRESP is tied to OKAY: error responses are not implemented in v1.
//
// Integration Notes
// - AHB-Lite is a pipelined, 2-phase protocol: the address phase (cycle N)
//   is always followed by the data phase (cycle N+1 at the earliest), even
//   for an "instant" slave. This module registers HADDR at the end of the
//   address phase and feeds the registered address to riscv_imem, so
//   HRDATA becomes valid exactly one cycle after the address phase, with
//   no extra wait states.
// - Address phase detection uses HTRANS[1], which is set for NONSEQ (2'b10)
//   and SEQ (2'b11) and clear for IDLE (2'b00) and BUSY (2'b01); this
//   slave does not need to distinguish NONSEQ from SEQ since it never
//   stalls or reorders.
// -----------------------------------------------------------------------------
module riscv_ahb_imem_slave #(
  parameter int    IMEM_WORDS    = 1024,
  parameter string IMEM_HEX_FILE = ""
) (
  input  logic        clk_i,
  input  logic        rst_ni,

  // AHB-Lite slave port (address/control driven by the master, data/status
  // driven by this slave).
  input  logic [31:0] haddr_i,
  input  logic [1:0]  htrans_i,
  input  logic        hwrite_i,
  input  logic [2:0]  hsize_i,
  output logic [31:0] hrdata_o,
  output logic        hready_o,
  output logic        hresp_o
);

  // HWRITE/HSIZE are not used by this read-only, word-only slave model;
  // kept as ports for AHB-Lite interface completeness.
  logic unused_hwrite;
  logic [2:0] unused_hsize;
  assign unused_hwrite = hwrite_i;
  assign unused_hsize  = hsize_i;

  // Identify an active address phase (NONSEQ or SEQ transfer).
  logic address_phase_valid;
  assign address_phase_valid = htrans_i[1];

  // Address-phase -> data-phase pipeline register: HADDR is captured at the
  // end of the address phase and used to address riscv_imem during the
  // following (data phase) cycle.
  logic [31:0] haddr_q;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      haddr_q <= 32'h0000_0000;
    end else if (address_phase_valid) begin
      haddr_q <= haddr_i;
    end
  end

  // Backing instruction memory (single word per access, zero-wait model).
  logic [31:0] imem_rdata;
  logic        imem_rvalid;

  riscv_imem #(
    .IMEM_WORDS    (IMEM_WORDS),
    .IMEM_HEX_FILE (IMEM_HEX_FILE)
  ) u_imem (
    .req_i    (1'b1),
    .addr_i   (haddr_q),
    .rdata_o  (imem_rdata),
    .rvalid_o (imem_rvalid)
  );

  // Zero-wait-state slave: data phase always completes the cycle right
  // after the address phase, so HREADY never needs to be deasserted.
  assign hrdata_o = imem_rdata;
  assign hready_o = 1'b1;
  assign hresp_o  = 1'b0; // OKAY; error responses not implemented in v1.

endmodule
