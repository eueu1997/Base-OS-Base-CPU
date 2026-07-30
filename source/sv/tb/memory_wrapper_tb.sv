// -----------------------------------------------------------------------------
// Module      : memory_wrapper_tb
// File        : memory_wrapper_tb.sv
// Author      : spt9pad
// Date        : 2026-07-27
// Version     : v1.0
//
// Functionality
// - Full testbench for memory_wrapper (set-associative cache + RAM + CDC).
// - Two asynchronous clocks: CPU 100 MHz, RAM ~133 MHz.
// - Address layout: addr[31:5]=tag(27b)  addr[4:2]=set(3b)  addr[1:0]=00
//
// Test plan
//   T1 : Write 4 words to 4 different sets.
//   T2 : Read back those 4 addresses (must be cache hits).
//   T3 : Read an address that was never written (must return 0 from RAM).
//   T4 : Write two different values to the same address (second wins).
//   T5 : Write-back eviction: write A, fill 3 more ways, evict A via write-
//        back to RAM, read A again – must return the written-back value.
//   T6 : Additional edge cases.
//        6.1 All 8 sets exercised.
//        6.2 Rapid double-write same address.
//        6.3 Full-set dirty eviction (4 writes to one set, 5th evicts oldest).
//        6.4 Cold read from unwritten address returns 0.
//        6.5 Four writes to same set followed by reads of the two newest.
//
// Notes on design behaviour captured by this TB
// - set_en_s is gated by !wb_needed_s (fix applied to set_associative_cache).
//   This prevents the shift chain from advancing while a writeback is pending,
//   ensuring RAM receives the correct (pre-eviction) way3 data.
// - do_write holds en_i=1 until hit_o=1.  The FSM may chain multiple
//   writebacks (one per dirty way3 encountered) before the write commits;
//   the 500-cycle timeout is generous enough to cover that chain.
// - do_read samples rdata_o after the first data_valid_w pulse
//   (hit_o | internal cache_wb_s).  For cache hits the data is captured one
//   cycle after the posedge that registered it; for RAM misses it is
//   the combinatorial pass-through on the ack cycle.
// -----------------------------------------------------------------------------
`timescale 1ns/1ps

module memory_wrapper_tb;

  // =========================================================================
  // Parameters
  // =========================================================================
  localparam int BLOCK_SIZE = 32;
  localparam int NUM_SETS   = 8;
  localparam int NUM_WAYS   = 4;
  localparam int TAG_SIZE   = 27;
  localparam int RAM_DEPTH  = 1024;

  localparam time T_CPU = 0.5ns;     // half-period → 100 MHz
  localparam time T_RAM = 3.76ns;  // half-period → ~133 MHz

  // =========================================================================
  // DUT I/O
  // =========================================================================
  logic        clk_cpu, clk_ram, rst_ni;
  logic        en_i;
  logic [31:0] addr_i;
  logic [31:0] wdata_i;
  logic        we_i;
  logic [31:0] rdata_o;
  logic        hit_o, miss_o;

  // =========================================================================
  // Hierarchical probes – control / status (simulation only)
  // =========================================================================
  // data_valid_w: CPU data word available (cache hit or RAM read-ack)
  wire  data_valid_w   = hit_o | u_dut.u_cache.cache_wb_s;
  // wb_pending_w: a write-back to RAM is currently in flight
  wire  wb_pending_w   = u_dut.u_cache.RAM_wr_req_o;

  // =========================================================================
  // Hierarchical probes – cache content for waveform visibility
  //
  // Per-set/per-way probes are exposed as 3 module-level matrices:
  //   cache_{tag,data,dirty}_m[set][way], with way ordered MRU(0)→LRU(3).
  //
  // Hierarchy path probed:
  //   u_dut.u_cache.g_cache_set[s].u_cache_set.wayN.data_s[58:32] → tag
  //   u_dut.u_cache.g_cache_set[s].u_cache_set.wayN.data_s[31:0]  → data
  //   u_dut.u_cache.g_cache_set[s].u_cache_set.wayN.dirty_q        → dirty
  //
  // Additional cache-level single wires (no set/way index):
  //   cache_fsm_w      – FSM state (3-bit: idle=0 read=1 read_miss=2
  //                      write=3 write_miss=4 writeback=5)
  //   cache_set_w      – set index decoded from current addr_i[4:2]
  //   cache_tag_w      – tag decoded from current addr_i[31:5]
  //   cache_wb_need_w  – writeback is pending before next operation
  // =========================================================================

  // -- Cache-level probes ---------------------------------------------------
  wire [2:0]          cache_fsm_w     = u_dut.u_cache.fsm_state_s;
  wire [2:0]          cache_set_w     = u_dut.u_cache.set_idx_s;
  wire [TAG_SIZE-1:0] cache_tag_w     = u_dut.u_cache.tag_s;
  wire                cache_wb_need_w = u_dut.u_cache.wb_needed_s;

  // Module-level per-set/per-way probe matrices
  wire [TAG_SIZE-1:0]   cache_tag_m   [0:NUM_SETS-1][0:NUM_WAYS-1];
  wire [BLOCK_SIZE-1:0] cache_data_m  [0:NUM_SETS-1][0:NUM_WAYS-1];
  wire                  cache_dirty_m [0:NUM_SETS-1][0:NUM_WAYS-1];

  // -- Per-set / per-way probes (generate) ----------------------------------
  generate
    for (genvar gs = 0; gs < NUM_SETS; gs++) begin : g_probe_set

      // way0 – MRU
        assign cache_tag_m[gs][0] =
          u_dut.u_cache.g_cache_set[gs].u_cache_set.way0.data_s[BLOCK_SIZE+TAG_SIZE-1:BLOCK_SIZE];
        assign cache_data_m[gs][0] =
          u_dut.u_cache.g_cache_set[gs].u_cache_set.way0.data_s[BLOCK_SIZE-1:0];
        assign cache_dirty_m[gs][0] =
          u_dut.u_cache.g_cache_set[gs].u_cache_set.way0.dirty_q;

      // way1
        assign cache_tag_m[gs][1] =
          u_dut.u_cache.g_cache_set[gs].u_cache_set.way1.data_s[BLOCK_SIZE+TAG_SIZE-1:BLOCK_SIZE];
        assign cache_data_m[gs][1] =
          u_dut.u_cache.g_cache_set[gs].u_cache_set.way1.data_s[BLOCK_SIZE-1:0];
        assign cache_dirty_m[gs][1] =
          u_dut.u_cache.g_cache_set[gs].u_cache_set.way1.dirty_q;

      // way2
        assign cache_tag_m[gs][2] =
          u_dut.u_cache.g_cache_set[gs].u_cache_set.way2.data_s[BLOCK_SIZE+TAG_SIZE-1:BLOCK_SIZE];
        assign cache_data_m[gs][2] =
          u_dut.u_cache.g_cache_set[gs].u_cache_set.way2.data_s[BLOCK_SIZE-1:0];
        assign cache_dirty_m[gs][2] =
          u_dut.u_cache.g_cache_set[gs].u_cache_set.way2.dirty_q;

      // way3 – LRU, eviction candidate (way3_dirty → writeback triggers)
        assign cache_tag_m[gs][3] =
          u_dut.u_cache.g_cache_set[gs].u_cache_set.way3.data_s[BLOCK_SIZE+TAG_SIZE-1:BLOCK_SIZE];
        assign cache_data_m[gs][3] =
          u_dut.u_cache.g_cache_set[gs].u_cache_set.way3.data_s[BLOCK_SIZE-1:0];
        assign cache_dirty_m[gs][3] =
          u_dut.u_cache.g_cache_set[gs].u_cache_set.way3.dirty_q;

    end
  endgenerate

  // =========================================================================
  // Reference model commit strobes
  //   wr_commit_w : write accepted by DUT (hit_o && we_i)
  //   rd_commit_w : read data valid from DUT (!we_i && data_valid_w)
  // =========================================================================
  wire wr_commit_w = hit_o & we_i;
  wire rd_commit_w = data_valid_w & ~we_i;

  // Reference model outputs
  wire [BLOCK_SIZE-1:0] ref_exp_comb_w;  // combinatorial expected data (current addr)
  wire [BLOCK_SIZE-1:0] ref_rdata_w;    // registered expected data (last rd_commit)
  wire                  ref_valid_w;    // 1-cycle pulse: ref_rdata_w just updated
  wire                  ref_match_w;    // 1=last read matched model, 0=mismatch
  wire                  ref_err_w;      // 1-cycle pulse on mismatch

  int  error_count = 0;

  // =========================================================================
  // DUT
  // =========================================================================
  memory_wrapper #(
    .NUM_SETS  (NUM_SETS),
    .NUM_WAYS  (NUM_WAYS),
    .BLOCK_SIZE(BLOCK_SIZE),
    .TAG_SIZE  (TAG_SIZE),
    .RAM_DEPTH (RAM_DEPTH)
  ) u_dut (
    .clk_cpu_i(clk_cpu),
    .clk_ram_i(clk_ram),
    .rst_ni   (rst_ni),
    .en_i     (en_i),
    .addr_i   (addr_i),
    .wdata_i  (wdata_i),
    .we_i     (we_i),
    .rdata_o  (rdata_o),
    .hit_o    (hit_o),
    .miss_o   (miss_o)
  );

  // =========================================================================
  // Reference golden model (runs in parallel with DUT)
  //
  // Tracks every committed write and provides the expected read data.
  // In the waveform compare:
  //   ref_exp_comb_w  – what the model expects RIGHT NOW for addr_i
  //   ref_rdata_w     – expected value sampled at the last read commit
  //   rdata_o         – DUT actual read data  (should equal ref_rdata_w)
  //   ref_match_w     – 1=OK, 0=mismatch on last read
  //   ref_err_w       – spike = mismatch event
  // =========================================================================
  mem_ref_model #(
    .DATA_W   (BLOCK_SIZE),
    .ADDR_W   (32),
    .MEM_DEPTH(RAM_DEPTH)
  ) u_ref (
    .clk_i        (clk_cpu),
    .rst_ni       (rst_ni),
    .we_i         (we_i),
    .addr_i       (addr_i),
    .wdata_i      (wdata_i),
    .wr_commit_i  (wr_commit_w),
    .rd_commit_i  (rd_commit_w),
    .dut_rdata_i  (rdata_o),
    .ref_exp_comb_o(ref_exp_comb_w),
    .ref_rdata_o  (ref_rdata_w),
    .ref_valid_o  (ref_valid_w),
    .ref_match_o  (ref_match_w),
    .ref_err_o    (ref_err_w)
  );

  // =========================================================================
  // Clocks
  // =========================================================================
  initial clk_cpu = 1'b0;
  always  #T_CPU clk_cpu = ~clk_cpu;

  initial clk_ram = 1'b0;
  always  #T_RAM clk_ram = ~clk_ram;

  // =========================================================================
  // Reset
  // =========================================================================
  initial begin
    rst_ni = 1'b0;
    repeat(8) @(posedge clk_cpu);
    @(negedge clk_cpu);
    rst_ni = 1'b1;
  end

  // =========================================================================
  // Real-time mismatch monitor
  // Prints a message every time the reference model detects a DUT mismatch.
  // =========================================================================
  always @(posedge clk_cpu) begin
    if (ref_exp_comb_w!=rdata_o && ref_valid_w) begin
      $display("[REF][MISMATCH] time=%0t  addr=0x%08h  exp=0x%08h  got=0x%08h",
               $time, addr_i, ref_exp_comb_w, rdata_o);
    end
  end

  // =========================================================================
  // Address builder: addr = { tag[26:0], set[2:0], 2'b00 }
  // =========================================================================
  function automatic logic [31:0] mkaddr(input int tag, input int set);
    return {tag[28:0], set[2:0]};
  endfunction

  // =========================================================================
  // Write task
  //
  // Hold en_i=1 until hit_o=1 (write acknowledged by cache).
  // The FSM may silently chain one or more writebacks (for each dirty way3
  // encountered during the shift chain); set_en_s is gated by wb_needed_s
  // so the write only commits once the writeback path is clear.
  // Timeout: 500 CPU cycles.
  // =========================================================================
  task automatic do_write(
    input  logic [31:0] addr,
    input  logic [31:0] data,
    input  string       label
  );
    int tmout = 0;
    @(negedge clk_cpu);
    en_i    = 1'b1;
    we_i    = 1'b1;
    addr_i  = addr;
    wdata_i = data;

    @(posedge clk_cpu);   // first posedge; let NBAs and comb settle
    /*while (!hit_o && tmout < 500) begin
      if (wb_pending_w)
        $display("[TB][INFO] %-30s  writeback in progress (wb_pending)", label);
      @(posedge clk_cpu); #1;
      tmout++;
    end
    if (tmout >= 500) begin
      $display("[TB][TIMEOUT] do_write %-30s  addr=0x%08h", label, addr);
      error_count++;
    end*/

    @(negedge clk_cpu);
    en_i    = 1'b0;
    we_i    = 1'b0;
    wdata_i = '0;
    //repeat(3) @(posedge clk_cpu);   // inter-transaction gap
  endtask

  // =========================================================================
  // Read task
  //
  // Hold en_i=1 until the first data_valid_w pulse:
  //   - hit_o=1      : cache hit; rdata_o = cached data (registered at posedge)
  //   - cache_wb_s=1 : RAM miss ack; rdata_o = RAM data (combinatorial)
  // In both cases rdata_o is stable #1 after the posedge thanks to the NBA
  // completion and subsequent comb settling.
  // Timeout: 500 CPU cycles.
  // =========================================================================
  task automatic do_read(
    input  logic [31:0] addr,
    output logic [31:0] data_out,
    input  string       label
  );
    int tmout = 0;
    @(negedge clk_cpu);
    en_i    = 1'b1;
    we_i    = 1'b0;
    addr_i  = addr;
    wdata_i = '0;

    @(posedge clk_cpu); #1;
    /*while (!data_valid_w && tmout < 500) begin
      @(posedge clk_cpu); #1;
      tmout++;
    end
    if (tmout >= 500) begin
      $display("[TB][TIMEOUT] do_read %-30s  addr=0x%08h", label, addr);
      error_count++;
    end*/
    data_out = rdata_o;   // sample after NBA + comb (post #1)

    @(negedge clk_cpu);
    en_i = 1'b0;
    we_i = 1'b0;
    repeat(3) @(posedge clk_cpu);   // inter-transaction gap
  endtask

  // =========================================================================
  // Check helper
  // =========================================================================
  task automatic chk(
    input logic [31:0] actual,
    input logic [31:0] expected,
    input string       label
  );
    if (actual !== expected) begin
      $display("[TB][FAIL] %-38s  exp=0x%08h  got=0x%08h",
               label, expected, actual);
      error_count++;
    end else
      $display("[TB][OK]   %-38s  = 0x%08h", label, actual);
  endtask

  // =========================================================================
  // Main test sequence
  // =========================================================================
  logic [31:0] rd;

  initial begin
    en_i    = 1'b0;
    we_i    = 1'b0;
    addr_i  = '0;
    wdata_i = '0;

    @(posedge rst_ni);
    repeat(4) @(posedge clk_cpu);

    // Pre-init RAM so reads of unwritten addresses return 0 (not X).
    for (int i = 0; i < RAM_DEPTH; i++) u_dut.u_ram.mem[i] = '0;

    // =====================================================================
    // TEST 1 – Write 4 words to 4 different sets (tag=1, sets 0-3)
    // =====================================================================
    $display("\n=== T1: Write 4 words to 4 different sets ===");
    do_write(mkaddr(1,0), 32'hDEAD_0001, "T1 W[tag=1,set=0]");
    do_write(mkaddr(2,0), 32'hDEAD_0002, "T1 W[tag=1,set=1]");
    do_write(mkaddr(3,0), 32'hDEAD_0003, "T1 W[tag=1,set=2]");
    do_write(mkaddr(4,0), 32'hDEAD_0004, "T1 W[tag=1,set=3]");

    // =====================================================================
    // TEST 2 – Read back those 4 addresses (must be cache hits)
    // =====================================================================
    $display("\n=== T2: Read back 4 addresses (expect cache hits) ===");
    do_read(mkaddr(1,0), rd, "T2 R[tag=1,set=0]"); chk(rd, 32'hDEAD_0001, "T2 set0");
    do_read(mkaddr(2,0), rd, "T2 R[tag=1,set=1]"); chk(rd, 32'hDEAD_0002, "T2 set1");
    do_read(mkaddr(3,0), rd, "T2 R[tag=1,set=2]"); chk(rd, 32'hDEAD_0003, "T2 set2");
    do_read(mkaddr(4,0), rd, "T2 R[tag=1,set=3]"); chk(rd, 32'hDEAD_0004, "T2 set3");

    // =====================================================================
    // TEST 3 – Read an address that was never written
    //          RAM pre-inited to 0 → must return 0 via the read-miss CDC path
    // =====================================================================
    $display("\n=== T3: Read unwritten address (expect 0 from RAM) ===");
    // tag=7, set=3 – guaranteed untouched by any previous transaction.
    do_read(mkaddr(5,0), rd, "T3 R unwritten [tag=7,set=3]");
    chk(rd, 32'h0000_0000, "T3 unwritten → 0");

    // =====================================================================
    // TEST 4 – Write two different values to the same address; second wins
    // =====================================================================
    $display("\n=== T4: Double write to same address ===");
    do_write(mkaddr(2,4), 32'hAAAA_AAAA, "T4 W1[tag=2,set=4]");
    do_write(mkaddr(2,4), 32'h5555_5555, "T4 W2[tag=2,set=4]");
    do_read (mkaddr(2,4), rd,            "T4 R [tag=2,set=4]");
    chk(rd, 32'h5555_5555, "T4 second write wins");

    // =====================================================================
    // TEST 5 – Write-back eviction test
    //
    //  (a) Write A(tag=11,set=0)=0xCAFE_0001 → stored in cache, dirty=1.
    //  (b) Read  A → cache hit  → CPU sees 0xCAFE_0001.
    //  (c) Write B(tag=12,set=0) → A shifts toward way3.
    //  (d) Write C(tag=13,set=0) → A shifts further.
    //  (e) Write D(tag=14,set=0) → A reaches way3 (dirty).
    //  (f) Write E(tag=15,set=0) → wb_needed_s=1 for A; FSM enters writeback,
    //                              sends A=0xCAFE_0001 to RAM, clears dirty3,
    //                              then commits E.
    //  (g) Read  A → cache miss  → RAM returns 0xCAFE_0001 (written back).
    //
    //  NOTE: The do_write tasks for (c)-(f) may each trigger additional
    //  intermediate writebacks as dirty entries propagate to way3 through
    //  the shift chain.  The task absorbs all of them transparently.
    // =====================================================================
    $display("\n=== T5: Write-back eviction test (set=0, tags 11-15) ===");

    // (a) Write A into the cache (way0, dirty).
    do_write(mkaddr(11,1), 32'hCAFE_0001, "T5.a W A[tag=11]");

    // (b) Read A: must hit in cache and return 0xCAFE_0001.
    do_read (mkaddr(11,1), rd,            "T5.b R A[tag=11]");
    chk(rd, 32'hCAFE_0001, "T5.b A in cache (hit)");

    // (c)-(e) Fill the remaining 3 ways of set=0 so A shifts to way3.
    do_write(mkaddr(12,1), 32'hBBBB_0002, "T5.c W B[tag=12]");
    do_write(mkaddr(13,1), 32'hCCCC_0003, "T5.d W C[tag=13]");
    do_write(mkaddr(14,1), 32'hDDDD_0004, "T5.e W D[tag=14]");

    // (f) Write E: triggers write-back of A from way3 to RAM.
    $display("[TB][INFO] T5.f: writing E – expect writeback of A to RAM");
    do_write(mkaddr(15,1), 32'hEEEE_0005, "T5.f W E[tag=15] → wb A");

    // (g) Read A: must miss in cache; RAM must return the written-back value.
    do_read (mkaddr(11,1), rd,            "T5.g R A[tag=11] after eviction");
    chk(rd, 32'hCAFE_0001, "T5.g A from RAM (write-back value correct)");

    // =====================================================================
    // TEST 6 – Additional edge cases
    // =====================================================================
    $display("\n=== T6: Additional edge cases ===");

    // -----------------------------------------------------------------------
    // TC 6.1 – All 8 sets exercised: write one entry per set then read back
    // -----------------------------------------------------------------------
    $display("--- TC6.1: write+read all 8 sets (tag=20) ---");
    for (int s = 0; s < 8; s++)
      do_write(mkaddr(20,s), 32'hF000_0000 | s[31:0], $sformatf("T6.1 W set%0d",s));
    for (int s = 0; s < 8; s++) begin
      do_read(mkaddr(20,s), rd, $sformatf("T6.1 R set%0d",s));
      chk(rd, 32'hF000_0000 | s[31:0], $sformatf("T6.1 set%0d",s));
    end

    // -----------------------------------------------------------------------
    // TC 6.2 – Rapid overwrite: two sequential writes to same address
    // -----------------------------------------------------------------------
    $display("--- TC6.2: rapid double-write same address (tag=30,set=6) ---");
    do_write(mkaddr(30,6), 32'h1111_2222, "T6.2 W1");
    do_write(mkaddr(30,6), 32'h3333_4444, "T6.2 W2");
    do_read (mkaddr(30,6), rd,            "T6.2 R" );
    chk(rd, 32'h3333_4444, "T6.2 last write visible");

    // -----------------------------------------------------------------------
    // TC 6.3 – Dirty eviction with full set: 4 writes to set=5 (dirty),
    //          5th write (different tag) evicts oldest via write-back,
    //          then reads back the evicted address from RAM.
    // -----------------------------------------------------------------------
    $display("--- TC6.3: full-set dirty eviction (set=5, tags 50-54) ---");
    do_write(mkaddr(50,5), 32'hAA50_AA50, "T6.3 W0 tag50");
    do_write(mkaddr(51,5), 32'hBB51_BB51, "T6.3 W1 tag51");
    do_write(mkaddr(52,5), 32'hCC52_CC52, "T6.3 W2 tag52");
    do_write(mkaddr(53,5), 32'hDD53_DD53, "T6.3 W3 tag53");
    $display("[TB][INFO] TC6.3: writing tag54 → expects writeback of tag50");
    do_write(mkaddr(54,5), 32'hEE54_EE54, "T6.3 W4 tag54→evict tag50");
    do_read (mkaddr(50,5), rd,            "T6.3 R tag50 from RAM");
    chk(rd, 32'hAA50_AA50, "T6.3 tag50 preserved in RAM after eviction");

    // -----------------------------------------------------------------------
    // TC 6.4 – Cold read of address untouched by all previous tests
    //          (tag=99, set=7, RAM=0) → must return 0 via miss path
    // -----------------------------------------------------------------------
    $display("--- TC6.4: cold cache miss returns 0 ---");
    do_read(mkaddr(99,7), rd, "T6.4 cold [tag=99,set=7]");
    chk(rd, 32'h0000_0000, "T6.4 cold read → 0");

    // -----------------------------------------------------------------------
    // TC 6.5 – Write 4 entries into the same set, then read back the
    //          two most recently written ones (they must still be in cache)
    // -----------------------------------------------------------------------
    $display("--- TC6.5: last two of 4 writes remain readable (set=2) ---");
    do_write(mkaddr(60,2), 32'hAAAA_6060, "T6.5 W tag60");
    do_write(mkaddr(61,2), 32'hBBBB_6161, "T6.5 W tag61");
    do_write(mkaddr(62,2), 32'hCCCC_6262, "T6.5 W tag62");
    do_write(mkaddr(63,2), 32'hDDDD_6363, "T6.5 W tag63");
    // way0=63 (MRU), way1=62 — both must still be in cache.
    do_read(mkaddr(63,2), rd, "T6.5 R tag63"); chk(rd, 32'hDDDD_6363, "T6.5 tag63 hit");
    do_read(mkaddr(62,2), rd, "T6.5 R tag62"); chk(rd, 32'hCCCC_6262, "T6.5 tag62 hit");

    // -----------------------------------------------------------------------
    // TC 6.6 – Write-back does not corrupt an unrelated set
    //          Write dirty data to set=0 (tag=70), then trigger a writeback
    //          in set=1 (by filling set=1 with 5 different tags), then verify
    //          set=0 tag=70 is still readable from cache or RAM.
    // -----------------------------------------------------------------------
    $display("--- TC6.6: writeback in set=1 does not disturb set=0 ---");
    do_write(mkaddr(70,0), 32'hCACA_7070, "T6.6 W set0 tag70");
    // Fill set=1 to trigger any writeback there.
    do_write(mkaddr(70,1), 32'h0001_7001, "T6.6 W set1 tag70");
    do_write(mkaddr(71,1), 32'h0002_7101, "T6.6 W set1 tag71");
    do_write(mkaddr(72,1), 32'h0003_7201, "T6.6 W set1 tag72");
    do_write(mkaddr(73,1), 32'h0004_7301, "T6.6 W set1 tag73");
    do_write(mkaddr(74,1), 32'h0005_7401, "T6.6 W set1 tag74 → wb in set1");
    // set=0 must be unaffected.
    do_read(mkaddr(70,0), rd, "T6.6 R set0 tag70");
    chk(rd, 32'hCACA_7070, "T6.6 set0 not disturbed by set1 writeback");

    // =====================================================================
    // TEST 7 – Random stress test
    //
    // 500 random read/write transactions over 128 possible addresses
    // (tags 100-115 × sets 0-7).  A shadow associative array tracks the
    // last value written at each address; every read result is verified
    // against it (0 for addresses never yet written, since RAM starts at 0).
    //
    // Address range (tags 100-115) is disjoint from all previous tests so
    // the RAM content for these addresses is guaranteed to be 0 at entry.
    //
    // With 16 candidate tags per set and a 4-way cache, each set undergoes
    // repeated evictions, exercising the full write-back path.  The
    // do_write/do_read tasks absorb chained writebacks transparently.
    //
    // The seed is fixed (42) for deterministic replay.
    // =====================================================================
    /*$display("\n=== T7: Random stress test (500 ops, tags 100-115, sets 0-7) ===");
    begin : stress_block
      // Shadow memory: addr → last data written by this test
      logic [31:0] shd [logic [31:0]];
      logic [31:0] saddr, sdata, sexp;
      int          sop, stag, sset, wr_n, rd_n, stress_err;

      wr_n = 0;  rd_n = 0;  stress_err = 0;
      $srandom(42);   // fixed seed – change to exercise different sequences

      for (int i = 0; i < 500; i++) begin
        sop  = $urandom_range(0, 99);
        stag = $urandom_range(100, 115);
        sset = $urandom_range(0, 7);
        saddr = mkaddr(stag, sset);

        if (sop < 60) begin
          // ---- WRITE ------------------------------------------------
          sdata      = $urandom();
          shd[saddr] = sdata;
          do_write(saddr, sdata,
                   $sformatf("T7 W[%3d] tag=%0d set=%0d", i, stag, sset));
          wr_n++;
        end else begin
          // ---- READ -------------------------------------------------
          sexp = shd.exists(saddr) ? shd[saddr] : 32'h0;
          do_read(saddr, rd,
                  $sformatf("T7 R[%3d] tag=%0d set=%0d", i, stag, sset));
          if (rd !== sexp) begin
            $display("[TB][FAIL] T7[%0d] tag=%0d set=%0d  exp=0x%08h got=0x%08h",
                     i, stag, sset, sexp, rd);
            stress_err++;
            error_count++;
          end else
            $display("[TB][OK]   T7[%0d] tag=%0d set=%0d  = 0x%08h",
                     i, stag, sset, rd);
          rd_n++;
        end

        // Progress report every 100 operations
        if ((i + 1) % 100 == 0)
          $display("[TB][T7] Progress %0d/500  W=%0d R=%0d Err=%0d",
                   i + 1, wr_n, rd_n, stress_err);
      end

      $display("[TB][T7] Complete. Writes=%0d Reads=%0d Errors=%0d",
               wr_n, rd_n, stress_err);
    end */

    // =====================================================================
    // Summary
    // =====================================================================
    repeat(5) @(posedge clk_cpu);
    $display("\n==========================================================");
    if (error_count == 0)
      $display("[TB][PASS] All checks passed.");
    else
      $display("[TB][FAIL] %0d error(s) detected.", error_count);
    $display("==========================================================\n");
    $finish;
  end

endmodule
