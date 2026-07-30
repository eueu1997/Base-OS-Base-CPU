// -----------------------------------------------------------------------------
// Module      : riscv_ahb_dmem_slave
// File        : riscv_ahb_dmem_slave.sv
// Author      : spt9pad
// Date        : 2026-07-30
// Version     : v1.0
//
// Functionality
// - AHB-Lite slave wrapper around riscv_dmem, acting as the bus-side backing
//   store reachable by the core's D-side AHB-Lite master port
//   (riscv_dcache_ctrl refill / dirty-line write-back path).
// - Read and write capable: unlike the read-only instruction-side slave,
//   this one must service both cache-miss refills (reads) and dirty-line
//   eviction write-backs (writes).
// - Word-only: riscv_dcache_ctrl/set_associative_cache only ever transfer a
//   single 32-bit word per line, so HSIZE is expected to always be WORD;
//   this slave forces a full-word access on riscv_dmem regardless of HSIZE
//   (byte/halfword granularity is handled entirely inside riscv_dcache_ctrl,
//   above this bus).
// - Zero-wait-state slave: HREADY is always driven high, because the
//   underlying riscv_dmem model completes a read/write in a single cycle.
// - HRESP is tied to OKAY: error responses are not implemented in v1.
//
// Integration Notes
// - Same address/data-phase pipelining as riscv_ahb_imem_slave: HADDR
//   (and, here, HWRITE/HWDATA) are registered at the end of the address
//   phase and fed to riscv_dmem the following cycle, so HRDATA/the write
//   commit land exactly one cycle after the address phase, with no extra
//   wait states.
// -----------------------------------------------------------------------------
module riscv_ahb_dmem_slave #(
  parameter int DMEM_WORDS = 1024
) (
  input  logic        clk_i,
  input  logic        rst_ni,

  // AHB-Lite slave port (address/control/write-data driven by the master,
  // read-data/status driven by this slave).
  input  logic [31:0] haddr_i,
  input  logic [1:0]  htrans_i,
  input  logic        hwrite_i,
  input  logic [2:0]  hsize_i,
  input  logic [31:0] hwdata_i,
  output logic [31:0] hrdata_o,
  output logic        hready_o,
  output logic        hresp_o
);

  // HSIZE is not evaluated by this word-only slave model; kept as a port
  // for AHB-Lite interface completeness.
  logic [2:0] unused_hsize;
  assign unused_hsize = hsize_i;

  // Data memory access width/sign-extension are fixed: this bus never
  // carries anything but full-word transfers.
  localparam logic [1:0] WIDTH_WORD = 2'b10;

  // Identify an active address phase (NONSEQ or SEQ transfer).
  logic address_phase_valid;
  assign address_phase_valid = htrans_i[1];

  // Address-phase -> data-phase pipeline registers: HADDR/HWRITE/HWDATA are
  // captured at the end of the address phase and used to drive riscv_dmem
  // during the following (data phase) cycle.
  logic [31:0] haddr_q;
  logic        hwrite_q;
  logic [31:0] hwdata_q;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      haddr_q  <= 32'h0000_0000;
      hwrite_q <= 1'b0;
      hwdata_q <= 32'h0000_0000;
    end else if (address_phase_valid) begin
      haddr_q  <= haddr_i;
      hwrite_q <= hwrite_i;
      hwdata_q <= hwdata_i;
    end
  end

  // Backing data memory (single word per access, zero-wait model, native
  // byte/halfword/word support -- only the word path is exercised here).
  logic [31:0] dmem_rdata;
  logic        dmem_rvalid;

  riscv_dmem #(
    .DMEM_WORDS (DMEM_WORDS)
  ) u_dmem (
    .clk_i      (clk_i),
    .req_i      (1'b1),
    .addr_i     (haddr_q),
    .we_i       (hwrite_q),
    .width_i    (WIDTH_WORD),
    .sign_ext_i (1'b0),
    .wdata_i    (hwdata_q),
    .rdata_o    (dmem_rdata),
    .rvalid_o   (dmem_rvalid)
  );

  // Zero-wait-state slave: data phase always completes the cycle right
  // after the address phase, so HREADY never needs to be deasserted.
  assign hrdata_o = dmem_rdata;
  assign hready_o = 1'b1;
  assign hresp_o  = 1'b0; // OKAY; error responses not implemented in v1.

endmodule
