// -----------------------------------------------------------------------------
// Module      : riscv_icache
// File        : riscv_icache.sv
// Author      : spt9pad
// Date        : 2026-07-28
// Version     : v1.0
//
// Functionality
// - Direct-mapped, read-only instruction cache for the IF stage.
// - Default geometry: 4 KB total, 128 lines, 8 words (32 bytes) per line.
// - Refills a full line on a miss over a read-only 256-bit AHB-Lite master
//   port using one transfer per cache line.
// - No write/dirty/writeback logic: instructions are not written back.
//
// Integration Notes
// - Core-side handshake (req_i/addr_i/rdata_o/rvalid_o) is unchanged and
//   local to the IF stage; rvalid_o is deasserted for the whole refill
//   duration on a miss, and the requester (riscv_if_stage) must hold the
//   fetch address and PC while rvalid_o is low.
// - The AHB-Lite master port is a reduced subset sufficient for a single,
//   non-bursting, read-only master: HADDR/HTRANS/HWRITE/HSIZE out,
//   HRDATA/HREADY/HRESP in. HBURST/HPROT are not driven (not needed by a
//   single-master, single-transfer-at-a-time port).
// - HRESP is sampled but not acted upon in v1 (no error/exception handling
//   yet, consistent with the rest of the core not implementing traps).
// - Fetch address must stay word-aligned (addr_i[1:0] == 2'b00).
// -----------------------------------------------------------------------------
module riscv_icache #(
  parameter int ICACHE_LINE_WORDS = 8,   // words per line (8 -> 256-bit line)
  parameter int ICACHE_NUM_LINES  = 128, // number of lines
  parameter int LINE_WORDS = 8,
  parameter int LINE_LENGHT = 2**LINE_WORDS  // line width in bits (default 256)
) (
  input  logic        clk_i,
  input  logic        rst_ni,

  // Core-side fetch interface (local to riscv_if_stage).
  input  logic        req_i,
  input  logic [31:0] addr_i,
  output logic [31:0] rdata_o,
  output logic        rvalid_o,

  // Read-only AHB-Lite master port toward the system bus (line refill path).
  output logic [31:0] ahb_haddr_o,
  output logic [1:0]  ahb_htrans_o,
  output logic        ahb_hwrite_o,
  output logic [2:0]  ahb_hsize_o,
  input  logic [LINE_LENGHT-1:0] ahb_hrdata_i,
  input  logic        ahb_hready_i,
  input  logic        ahb_hresp_i
);

  // AHB-Lite HTRANS encoding (subset used by this read-only master).
  localparam logic [1:0] HTRANS_IDLE   = 2'b00;
  localparam logic [1:0] HTRANS_NONSEQ = 2'b10;
  // AHB-Lite HSIZE encoding: line-wide transfers only (32 B when LINE_WORDS=8).
  localparam logic [2:0] HSIZE_LINE    = 3'($clog2(LINE_WORDS) + 2);

  localparam int RAW_OFFSET_BITS = (ICACHE_LINE_WORDS > 1) ? $clog2(ICACHE_LINE_WORDS) : 0;
  localparam int OFFSET_BITS     = (RAW_OFFSET_BITS > 0) ? RAW_OFFSET_BITS : 1;
  localparam int INDEX_BITS  = $clog2(ICACHE_NUM_LINES);
  localparam int TAG_BITS    = 32 - INDEX_BITS - RAW_OFFSET_BITS - 2;

  // Address breakdown of the current fetch address.
  logic [TAG_BITS-1:0]    req_tag;
  logic [INDEX_BITS-1:0]  req_index;
  logic [OFFSET_BITS-1:0] req_word_off;
  logic [31:0]            req_line_base_addr;

  // Cache storage: one valid bit and one tag per line, line data words.
  logic                 valid_q [0:ICACHE_NUM_LINES-1];
  logic [TAG_BITS-1:0]  tag_q   [0:ICACHE_NUM_LINES-1];
  logic [31:0]          data_q  [0:ICACHE_NUM_LINES-1][0:ICACHE_LINE_WORDS-1];
  // Refill FSM state.
  logic                   refill_active_q;
  logic [TAG_BITS-1:0]    refill_tag_q;
  logic [INDEX_BITS-1:0]  refill_index_q;

  // Hit detection for the current request (no hit while a refill is in flight).
  logic hit;

  assign req_tag      = addr_i[31:32-TAG_BITS];
  assign req_index    = addr_i[2+RAW_OFFSET_BITS +: INDEX_BITS];

  always_comb begin
    req_word_off = '0;
    if (RAW_OFFSET_BITS > 0) begin
      req_word_off = addr_i[2 +: RAW_OFFSET_BITS];
    end

    // Base address of the cache line being refilled.
    req_line_base_addr = addr_i;
    if (RAW_OFFSET_BITS > 0) begin
      req_line_base_addr[2 +: RAW_OFFSET_BITS] = '0;
    end
  end


  // Registered AHB-Lite master outputs. AHB-Lite requires HADDR/HTRANS to
  // stay stable for the whole address+data phase (including wait states
  // while ahb_hready_i is low), so they are driven from registers rather
  // than combinationally from the miss/refill state.
  logic [31:0] ahb_haddr_q;
  logic [1:0]  ahb_htrans_q;

  assign ahb_haddr_o  = ahb_haddr_q;
  assign ahb_htrans_o = ahb_htrans_q;
  assign ahb_hwrite_o = 1'b0;      // read-only master: never issues writes.
  assign ahb_hsize_o  = HSIZE_LINE;

  // Cache hit: combinational single-cycle response, unchanged from before.
  // Cache miss: rvalid_o stays low until the AHB line refill completes.
  assign rdata_o  = hit ? data_q[req_index][req_word_off] : 32'h0000_0000;
  assign rvalid_o = hit;
  assign hit = req_i & valid_q[req_index] & (tag_q[req_index] == req_tag) & ~refill_active_q;

  // Refill FSM, AHB-Lite master sequencing and cache array update.
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      refill_active_q <= 1'b0;
      refill_tag_q    <= '0;
      refill_index_q  <= '0;
      ahb_haddr_q     <= 32'h0000_0000;
      ahb_htrans_q    <= HTRANS_IDLE;
      for (int i = 0; i < ICACHE_NUM_LINES; i++) begin
        valid_q[i] <= 1'b0;
      end
    end else begin
      if (!refill_active_q) begin
        // Start a line refill on a miss: issue the AHB address phase for the
        // first word of the line (offset 0).
        if (req_i & !hit) begin
          refill_active_q <= 1'b1;
          refill_tag_q    <= req_tag;
          refill_index_q  <= req_index;
          ahb_haddr_q     <= req_line_base_addr;
          ahb_htrans_q    <= HTRANS_NONSEQ;
        end else begin
          ahb_htrans_q <= HTRANS_IDLE;
        end
      end else if (!ahb_hready_i) begin
        // Wait state: slave not ready yet, keep HADDR/HTRANS stable and wait.
        ahb_haddr_q  <= ahb_haddr_q;
        ahb_htrans_q <= ahb_htrans_q;
      end else begin
        // ahb_hready_i high: data phase completes this cycle and ahb_hrdata_i
        // contains one whole cache line. Unpack all 32-bit words into the line.
        for (int w = 0; w < ICACHE_LINE_WORDS; w++) begin
          data_q[refill_index_q][w] <= ahb_hrdata_i[(w+1)*32-1 -: 32];
        end

        valid_q[refill_index_q] <= 1'b1;
        tag_q[refill_index_q]   <= refill_tag_q;
        refill_active_q         <= 1'b0;
        ahb_htrans_q            <= HTRANS_IDLE;
      end
    end
  end

endmodule
