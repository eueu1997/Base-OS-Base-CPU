`timescale 1ns/1ps

// -----------------------------------------------------------------------------
// Module      : riscv_icache_tb
// File        : riscv_icache_tb.sv
// Author      : spt9pad
// Date        : 2026-07-29
// Version     : v1.0
//
// Functionality
// - Standalone testbench for riscv_icache, driven directly at its core-side
//   fetch interface (req_i/addr_i/rdata_o/rvalid_o).
// - Models the AHB-Lite slave side with a simple identity memory (returned
//   word data == its own word address), so any addressing/refill-sequencing
//   bug shows up directly as a data mismatch.
// - Exercises: cold miss + line hit-after-refill, a second line (different
//   index), direct-mapped conflict eviction, and refill with injected AHB
//   wait states.
// - Also runs continuous AHB-Lite protocol sanity checks on the master port
//   (read-only/word-only, HADDR/HTRANS held stable during wait states).
//
// Integration Notes
// - Uses a small, non-default cache geometry (4 lines x 4 words = 64 B) to
//   keep the tag/index/offset arithmetic easy to follow and to reach a
//   conflict-miss scenario with only a couple of test addresses.
// -----------------------------------------------------------------------------
module riscv_icache_tb;

  localparam time CLK_PERIOD = 10ns;
  localparam int  ICACHE_LINE_WORDS_TB = 4;  // 16 B lines
  localparam int  ICACHE_NUM_LINES_TB  = 4;  // 64 B total
  localparam int  TIMEOUT_CYCLES       = 50; // deadlock guard for fetch_and_check

  // AHB-Lite HTRANS/HSIZE encodings, mirrored here for verification only.
  localparam logic [1:0] HTRANS_IDLE   = 2'b00;
  localparam logic [1:0] HTRANS_NONSEQ = 2'b10;
  localparam logic [2:0] HSIZE_WORD    = 3'b010;

  logic        clk;
  logic        rst_n;

  // Core-side fetch interface.
  logic        req_i;
  logic [31:0] addr_i;
  logic [31:0] rdata_o;
  logic        rvalid_o;

  // AHB-Lite master port under test.
  logic [31:0] ahb_haddr;
  logic [1:0]  ahb_htrans;
  logic        ahb_hwrite;
  logic [2:0]  ahb_hsize;
  logic [31:0] ahb_hrdata;
  logic        ahb_hready;
  logic        ahb_hresp;

  int error_count_i,error_count;

  // Testbench-controlled number of extra AHB wait states injected by the
  // slave model on every transfer (0 = zero-wait-state slave).
  int unsigned tb_wait_cycles;

  // DUT instance.
  riscv_icache #(
    .ICACHE_LINE_WORDS (ICACHE_LINE_WORDS_TB),
    .ICACHE_NUM_LINES  (ICACHE_NUM_LINES_TB)
  ) u_dut (
    .clk_i        (clk),
    .rst_ni       (rst_n),
    .req_i        (req_i),
    .addr_i       (addr_i),
    .rdata_o      (rdata_o),
    .rvalid_o     (rvalid_o),
    .ahb_haddr_o  (ahb_haddr),
    .ahb_htrans_o (ahb_htrans),
    .ahb_hwrite_o (ahb_hwrite),
    .ahb_hsize_o  (ahb_hsize),
    .ahb_hrdata_i (ahb_hrdata),
    .ahb_hready_i (ahb_hready),
    .ahb_hresp_i  (ahb_hresp)
  );

  // Clock generator.
  initial begin
    clk = 1'b0;
    forever #(CLK_PERIOD/2) clk = ~clk;
  end

  // Reset sequence.
  initial begin
    rst_n          = 1'b0;
    req_i          = 1'b0;
    addr_i         = 32'h0000_0000;
    tb_wait_cycles = 0;
    repeat (3) @(posedge clk);
    rst_n = 1'b1;
  end

  // -----------------------------------------------------------------------
  // AHB-Lite slave model: identity memory (data == address), with
  // tb_wait_cycles extra wait states injected on every transfer. Only
  // change tb_wait_cycles while the cache is idle (between fetch_and_check
  // calls), otherwise the wait count applied to an in-flight transfer would
  // change mid-transfer.
  // -----------------------------------------------------------------------
  logic       slave_busy_q;
  logic [7:0] slave_wait_cnt_q;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      slave_busy_q     <= 1'b0;
      slave_wait_cnt_q <= '0;
    end else begin
      if (!slave_busy_q) begin
        if (ahb_htrans[1] && (tb_wait_cycles != 0)) begin
          slave_busy_q     <= 1'b1;
          slave_wait_cnt_q <= tb_wait_cycles[7:0] - 8'd1;
        end
      end else begin
        if (slave_wait_cnt_q == 0) begin
          slave_busy_q <= 1'b0;
        end else begin
          slave_wait_cnt_q <= slave_wait_cnt_q - 8'd1;
        end
      end
    end
  end

  // Zero-wait case: hready stays high as soon as tb_wait_cycles == 0.
  // Wait-state case: hready is low until slave_wait_cnt_q reaches 0.
  assign ahb_hready = slave_busy_q ? (slave_wait_cnt_q == 0)
                                    : (!ahb_htrans[1] || (tb_wait_cycles == 0));
  // Identity memory: data phase always reflects the currently held address.
  assign ahb_hrdata = ahb_haddr;
  assign ahb_hresp  = 1'b0; // OKAY; error responses are not exercised here.

  // -----------------------------------------------------------------------
  // Continuous AHB-Lite protocol sanity checks on the master port.
  // -----------------------------------------------------------------------
  logic [31:0] prev_haddr_q;
  logic [1:0]  prev_htrans_q;
  logic        prev_hready_q;
  logic        prev_valid_q;
  logic        error_count_q;
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      prev_haddr_q  <= 32'h0000_0000;
      prev_htrans_q <= HTRANS_IDLE;
      prev_hready_q <= 1'b1;
      prev_valid_q  <= 1'b0;
    end else begin
      // Read-only, word-only master: must hold on every cycle.
      if (ahb_hwrite !== 1'b0) begin
        $display("[TB][ERROR] AHB protocol: hwrite_o asserted unexpectedly");
        error_count_q <= error_count_q + 1'b1;
      end
      if (ahb_htrans[1] && (ahb_hsize !== HSIZE_WORD)) begin
        $display("[TB][ERROR] AHB protocol: hsize_o != WORD during an active transfer");
        error_count_q <= error_count_q + 1'b1;
      end
      // If the previous cycle left a transfer in a wait state (active
      // transfer, hready low), HADDR/HTRANS must not have changed.
      if (prev_valid_q && prev_htrans_q[1] && !prev_hready_q) begin
        if ((ahb_haddr !== prev_haddr_q) || (ahb_htrans !== prev_htrans_q)) begin
          $display("[TB][ERROR] AHB protocol: HADDR/HTRANS changed during a wait state (addr 0x%08h -> 0x%08h)",
                    prev_haddr_q, ahb_haddr);
          error_count_q <= error_count_q + 1'b1;
        end
      end
      prev_haddr_q  <= ahb_haddr;
      prev_htrans_q <= ahb_htrans;
      prev_hready_q <= ahb_hready;
      prev_valid_q  <= 1'b1;
    end
  end

  // -----------------------------------------------------------------------
  // Fetch-and-check task: drives a fetch request and waits for rvalid_o,
  // checking the returned data against the identity-memory model.
  // -----------------------------------------------------------------------
  task automatic fetch_and_check(input logic [31:0] addr, input string label);
    int cycles;
    begin
      req_i  = 1'b1;
      addr_i = addr;
      #1;
      cycles = 0;
      while (!rvalid_o && (cycles < TIMEOUT_CYCLES)) begin
        @(posedge clk);
        #1;
        cycles++;
      end

      if (!rvalid_o) begin
        $display("[TB][ERROR] %s: timeout waiting for rvalid_o (addr=0x%08h)", label, addr);
        error_count_i++;
      end else if (rdata_o !== addr) begin
        $display("[TB][ERROR] %s: data mismatch addr=0x%08h expected=0x%08h actual=0x%08h",
                  label, addr, addr, rdata_o);
        error_count_i++;
      end else begin
        $display("[TB][OK]    %s: addr=0x%08h data=0x%08h (%0d cycles)", label, addr, rdata_o, cycles);
      end
    end
  endtask

  // Test sequence.
  initial begin
    error_count = 0;
    error_count_i = 0;

    @(posedge rst_n);
    @(posedge clk);

    $display("\n=== Cold miss + line hit-after-refill (line 0) ===");
    fetch_and_check(32'h0000_0000, "miss  word0/line0");
    fetch_and_check(32'h0000_0004, "hit   word1/line0");
    fetch_and_check(32'h0000_0008, "hit   word2/line0");
    fetch_and_check(32'h0000_000C, "hit   word3/line0");

    $display("\n=== Second line, different index (index 1) ===");
    fetch_and_check(32'h0000_0010, "miss  word0/line1");
    fetch_and_check(32'h0000_0014, "hit   word1/line1");
    fetch_and_check(32'h0000_001C, "hit   word3/line1");

    $display("\n=== Direct-mapped conflict eviction (same index 0, different tag) ===");
    fetch_and_check(32'h0000_0040, "miss  new tag @ index0 (evicts line0)");
    fetch_and_check(32'h0000_0000, "miss  original tag @ index0 (thrash)");
    fetch_and_check(32'h0000_0004, "hit   word1 of re-refilled line0");

    $display("\n=== Refill with injected AHB wait states ===");
    tb_wait_cycles = 2;
    fetch_and_check(32'h0000_0020, "miss  word0/line2 (2 wait states/xfer)");
    fetch_and_check(32'h0000_0024, "hit   word1/line2");
    tb_wait_cycles = 0;
    error_count = error_count_i + error_count_q;
    if (error_count == 0) begin
      $display("\n[TB][PASS] riscv_icache_tb passed");
    end else begin
      $display("\n[TB][FAIL] riscv_icache_tb errors=%0d", error_count);
    end

    $finish;
  end

endmodule
