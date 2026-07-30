// -----------------------------------------------------------------------------
// Module      : riscv_ahb_ram_slave
// File        : riscv_ahb_ram_slave.sv
// Author      : spt9pad
// Date        : 2026-07-29
// Version     : v1.0
//
// Functionality
// - Unified AHB-Lite RAM slave used as common backing memory for both
//   instruction-cache refills and data-cache refill/write-back traffic.
// - Exposes a 4 GB byte address space (32-bit address).
// - Supports one read or one write transaction at a time.
// - Storage is modeled as sparse associative memory to avoid allocating a
//   full 4 GB array in simulation.
// - Zero wait-state from the slave point of view (HREADY always high).
//
// Integration Notes
// - AHB-Lite is pipelined: address/control sampled in cycle N, read data
//   returned in cycle N+1. This module registers address/control/write data
//   and performs the memory operation in the following cycle.
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
  parameter string BOOT_HEX_FILE = "",
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

  localparam int LINE_ADDR_LSB = $clog2(LINE_WORDS) + 2;

  // Sparse line-addressable storage:
  // key   = addr[31:LINE_ADDR_LSB]
  // value = one full line (LINE_LENGHT bits).
  int unsigned line_addr;
  logic [LINE_LENGHT-1:0] ram_sparse [int unsigned];

  // Optional preload image buffer (word-based input, then packed per line).
  logic [31:0] boot_word_image [0:BOOT_WORDS-1];

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

  // AHB-Lite status outputs: always ready, always OKAY in this v1 model.
  assign hready_o = 1'b1;
  assign hresp_o  = 1'b0;

  // Read-data mux from last sampled request.
  always_comb begin
    hrdata_o  = {LINE_LENGHT{1'b0}};
    line_addr = addr_q[31:LINE_ADDR_LSB];
    if (req_q && !write_q && ram_sparse.exists(line_addr)) begin
      hrdata_o = ram_sparse[line_addr];
    end
  end

  // Register address/control and apply writes in the following cycle.
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      req_q   <= 1'b0;
      write_q <= 1'b0;
      addr_q  <= 32'h0000_0000;
      wdata_q <= {LINE_LENGHT{1'b0}};
    end else begin
      // Data phase action for previously sampled request.
      if (req_q && write_q) begin
        int unsigned wr_line_addr;
        int unsigned wr_lane_idx;

        wr_line_addr = addr_q[31:LINE_ADDR_LSB];
        wr_lane_idx  = addr_q[$clog2(LINE_WORDS)+1:2];

        if (!ram_sparse.exists(wr_line_addr)) begin
          ram_sparse[wr_line_addr] = {LINE_LENGHT{1'b0}};
        end

        ram_sparse[wr_line_addr][(wr_lane_idx+1)*32-1 -: 32] =
          wdata_q[(wr_lane_idx+1)*32-1 -: 32];
      end

      // Sample new address/control phase.
      req_q   <= address_phase_valid;
      write_q <= hwrite_i;
      addr_q  <= haddr_i;
      wdata_q <= hwdata_i;
    end
  end

  // Optional boot preload. Memory is sparse, so only explicitly loaded words
  // are allocated; all other addresses read as zero.
  initial begin : init_sparse_ram
    int i;
    int j;
    int line_key;
    int lane_idx;
    for (i = 0; i < BOOT_WORDS; i++) begin
      boot_word_image[i] = 32'h0000_0000;
    end

    if (BOOT_HEX_FILE != "") begin
      $readmemh(BOOT_HEX_FILE, boot_word_image);
      for (i = 0; i < BOOT_WORDS; i++) begin
        line_key = i / LINE_WORDS;
        lane_idx = i % LINE_WORDS;

        if (!ram_sparse.exists(line_key)) begin
          ram_sparse[line_key] = {LINE_LENGHT{1'b0}};
        end

        ram_sparse[line_key][(lane_idx+1)*32-1 -: 32] = boot_word_image[i];
      end

      // Ensure every line that has at least one initialized word exists.
      for (j = 0; j < (BOOT_WORDS + LINE_WORDS - 1) / LINE_WORDS; j++) begin
        if (!ram_sparse.exists(j)) begin
          ram_sparse[j] = {LINE_LENGHT{1'b0}};
        end
      end
    end
  end

endmodule
