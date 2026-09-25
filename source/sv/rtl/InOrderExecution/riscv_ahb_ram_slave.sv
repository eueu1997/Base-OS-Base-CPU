// -----------------------------------------------------------------------------
// Module      : riscv_ahb_ram_slave
// File        : riscv_ahb_ram_slave.sv
// Author      : spt9pad
// Date        : 2026-07-29
// Version     : v1.1
//
// Functionality
// - Unified AHB-Lite RAM slave used as common backing memory for both
//   instruction-cache refills and data-cache refill/write-back traffic.
// - Exposes a 4 GB byte address space (32-bit address).
// - Supports one read or one write transaction at a time.
// - Storage lives in riscv_ram_sparse, instantiated below, so the memory
//   array can be swapped for a synthesis black box independently of this
//   AHB-Lite protocol logic.
// - Zero wait-state from the slave point of view (HREADY always high).
//
// Integration Notes
// - AHB-Lite is pipelined: address/control sampled in cycle N, read data
//   returned in cycle N+1. This module registers address/control/write data
//   and drives riscv_ram_sparse's read/write port from those registered
//   values one cycle later.
// - Bus payload is line-wide (LINE_LENGHT bits, 256 by default). For writes,
//   only the 32-bit lane selected by the address is committed into RAM.
//   This lets the D-cache keep internal 32-bit semantics while using a
//   256-bit shared AHB payload.
// - Uninitialized locations read as zero.
// - Optional boot image preload can initialize the first BOOT_WORDS words
//   starting at address 0x0000_0000.
// -----------------------------------------------------------------------------
module riscv_ahb_ram_slave #(
  parameter int    BOOT_WORDS    = 1024,
  parameter int    LINE_WORDS  = 8,
  parameter int    LINE_LENGHT = 2**LINE_WORDS
) (
  input  logic        clk_i,
  input  logic        rst_ni,

  input  logic [31:0] haddr_i,
  input  logic [1:0]  htrans_i,
  input  logic        hwrite_i,
  input  logic [2:0]  hsize_i,
  input  logic [LINE_LENGHT-1:0] hwdata_i,

  output logic [LINE_LENGHT-1:0] hrdata_o,
  output logic        hready_o,
  output logic        hresp_o
);

  // Keep HSIZE as a formal port for interface completeness.
  logic [2:0] unused_hsize;
  assign unused_hsize = hsize_i;

  // Registered address phase (consumed one cycle later in data phase).
  logic        req_q;
  logic        write_q;
  logic [31:0] addr_q;
  logic [LINE_LENGHT-1:0] wdata_q;

  // Address phase is active when HTRANS indicates NONSEQ/SEQ.
  logic address_phase_valid;
  assign address_phase_valid = htrans_i[1];

  // Backing storage, isolated so it can be replaced by a synthesis black box.
  riscv_ram_sparse #(
    .BOOT_WORDS    (BOOT_WORDS),
    .LINE_WORDS    (LINE_WORDS),
    .LINE_LENGHT   (LINE_LENGHT)
  ) u_ram (
    .clk_i   (clk_i),
    .rst_ni  (rst_ni),
    .addr_i  (haddr_i),
    .req_i   (address_phase_valid),
    .we_i    (hwrite_i),
    .wdata_i (hwdata_i),
    .rdata_o (hrdata_o),
    .hready_o (hready_o),
    .hresp_o  (hresp_o)
  );

endmodule
