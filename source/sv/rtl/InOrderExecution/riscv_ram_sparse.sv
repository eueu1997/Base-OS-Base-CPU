// -----------------------------------------------------------------------------
// Module      : riscv_ram_sparse
// File        : riscv_ram_sparse.sv
// Author      : spt9pad
// Date        : 2026-09-07
// Version     : v1.0
//
// Functionality
// - Sparse associative storage backing riscv_ahb_ram_slave, isolated so the
//   non-synthesizable memory array can be swapped for a synthesis black box
//   while the AHB-Lite protocol logic in riscv_ahb_ram_slave stays intact.
// - Storage is line-addressable (LINE_LENGHT bits per line); a write only
//   commits the 32-bit lane selected by addr_i within its line.
// - Read is combinational on addr_i; uninitialized lines read as zero.
// - Optional boot image preload initializes the first BOOT_WORDS words
//   starting at address 0x0000_0000.
// -----------------------------------------------------------------------------
module riscv_ram_sparse #(
  parameter int    BOOT_WORDS    = 1024,
  parameter int    LINE_WORDS    = 8,
  parameter int    LINE_LENGHT   = 2**LINE_WORDS
) (
  input  logic        clk_i,
  input  logic        rst_ni,

  input  logic [31:0] addr_i,
  input  logic         we_i,
  input  logic        req_i,
  input  logic [LINE_LENGHT-1:0] wdata_i,

  output logic [LINE_LENGHT-1:0] rdata_o
);
`ifndef SYNTHESIS
  localparam string BOOT_HEX_FILE = "";
  // Synthesis black box for sparse RAM storage.
  localparam int LINE_ADDR_LSB = $clog2(LINE_WORDS) + 2;

  // Sparse line-addressable storage:
  // key   = addr[31:LINE_ADDR_LSB]
  // value = one full line (LINE_LENGHT bits).
  logic [LINE_LENGHT-1:0] ram_sparse [int unsigned];

  // Optional preload image buffer (word-based input, then packed per line).
  logic [31:0] boot_word_image [0:BOOT_WORDS-1];

  // Combinational line read; uninitialized lines read as zero.
  always_comb begin

  end

  // Synchronous write of the addressed 32-bit lane within its line.
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      // Storage content is not reset; unallocated lines already read as zero.
      hready_o = 1'b1;
      hresp_o  = 1'b0;
    end else if (req_i) begin
      hready_o = 1'b0;
      if (we_i) begin
      int unsigned wr_line_addr;
      int unsigned wr_lane_idx;

      wr_line_addr = addr_i[31:LINE_ADDR_LSB];
      wr_lane_idx  = addr_i[$clog2(LINE_WORDS)+1:2];

      if (!ram_sparse.exists(wr_line_addr)) begin
        ram_sparse[wr_line_addr] = {LINE_LENGHT{1'b0}};
      end

      ram_sparse[wr_line_addr][(wr_lane_idx+1)*32-1 -: 32] = wdata_i[(wr_lane_idx+1)*32-1 -: 32];

      end else begin
        int unsigned rd_line_addr;
        rd_line_addr = addr_i[31:LINE_ADDR_LSB];
        rdata_o = ram_sparse.exists(rd_line_addr) ? ram_sparse[rd_line_addr] : {LINE_LENGHT{1'b0}};
      end
    end else
      // No operation; maintain current read data.
      hready_o = 1'b1;
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

`endif
endmodule
