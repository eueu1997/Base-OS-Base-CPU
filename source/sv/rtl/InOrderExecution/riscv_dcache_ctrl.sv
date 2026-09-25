// -----------------------------------------------------------------------------
// Module      : riscv_dcache_ctrl
// File        : riscv_dcache_ctrl.sv
// Author      : spt9pad
// Date        : 2026-07-29
// Version     : v1.0
//
// Functionality
// - Wraps set_associative_cache to provide the same core-side memory
//   interface previously offered by riscv_dmem (req/addr/we/width/sign_ext/
//   wdata -> rdata/rvalid), plus a stall output for the WB stage/pipeline.
// - set_associative_cache only stores whole 32-bit words and has no
//   byte/halfword support: this controller performs the width/sign
//   extension for loads, and a read-modify-write sequence for partial
//   stores (sb/sh), so lb/lh/lw/lbu/lhu/sb/sh/sw all keep working.
// - Drives a read/write AHB-Lite master port to service the cache's
//   RAM_read_*/RAM_wr_* handshake (line refill on a read miss, write-back
//   of an evicted dirty line), reusing the same style of AHB master FSM as
//   riscv_icache (registered HADDR/HTRANS held stable through wait states).
//
// Integration Notes
// - set_associative_cache exposes no explicit "operation done" signal: an
//   access may need an eviction write-back before it can proceed, and that
//   need only becomes visible on RAM_wr_req_o one cycle after the fact.
//   This controller therefore considers an access complete only after 2
//   consecutive cycles with RAM_read_req_o and RAM_wr_req_o both low
//   (bounded, generic "quiescence" detection that covers this 1-cycle
//   detection lag regardless of which internal path was taken).
// - stall_o freezes the calling stage's own output registers (ID/EX) for
//   the whole access, so load_valid/load_rd stay correctly paired with the
//   in-flight instruction until WB consumes the result. Because that
//   freeze/unfreeze is itself a registered effect (one cycle to take
//   effect), simply dropping stall_o the instant the access settles would
//   let dcache_ctrl observe a stale, not-yet-updated req_i and either
//   re-dispatch the same finished transaction forever (livelock) or race
//   with ID/EX's register update. Two extra fixed "handoff" states
//   (ST_DONE_A/ST_DONE_B, see the FSM comment below) close this gap at the
//   cost of a couple of extra cycles per access.
// - Known simplification: a line fetched to service a read miss is NOT
//   written back into the cache array (no write-allocate-on-load-miss).
//   The returned load value is always correct (taken directly from the
//   AHB read), but repeated loads to that line will keep missing until a
//   store touches it. Stores always populate/refresh the cache. This
//   keeps the controller simpler; revisit if read-miss locality matters.
// - stall_o must be held by the caller (WB stage) to freeze the whole
//   pipeline (ID/EX output registers and, transitively, IF) for as long as
//   an access is in flight, exactly like the existing load-use stall.
// -----------------------------------------------------------------------------
module riscv_dcache_ctrl #(
  parameter int NUM_SETS = 8,
  parameter int NUM_WAYS = 4,
  parameter int TAG_SIZE = 27,
  parameter int LINE_WORDS  = 8,
  parameter int LINE_LENGHT = 2**LINE_WORDS
) (
  input  logic        clk_i,
  input  logic        rst_ni,

  // Core-side memory interface (mirrors riscv_dmem's port list).
  input  logic        req_i,
  input  logic [31:0] addr_i,
  input  logic        we_i,
  input  logic [1:0]  width_i,
  input  logic        sign_ext_i,
  input  logic [31:0] wdata_i,
  output logic [31:0] rdata_o,
  output logic        rvalid_o,
  output logic        stall_o,

  // Read/write AHB-Lite master port toward the system bus (line refill and
  // dirty-line write-back path).
  output logic [31:0] ahb_haddr_o,
  output logic [1:0]  ahb_htrans_o,
  output logic        ahb_hwrite_o,
  output logic [2:0]  ahb_hsize_o,
  output logic [LINE_LENGHT-1:0] ahb_hwdata_o,
  input  logic [LINE_LENGHT-1:0] ahb_hrdata_i,
  input  logic        ahb_hready_i,
  input  logic        ahb_hresp_i
);

  // AHB-Lite HTRANS/HSIZE encodings (see riscv_icache for the same subset).
  localparam logic [1:0] HTRANS_IDLE   = 2'b00;
  localparam logic [1:0] HTRANS_NONSEQ = 2'b10;
  localparam logic [2:0] HSIZE_LINE    = 3'($clog2(LINE_WORDS) + 2);

  // Access widths on the core-side interface (mirrors riscv_dmem's encoding).
  localparam logic [1:0] WIDTH_BYTE = 2'b00;
  localparam logic [1:0] WIDTH_HALF = 2'b01;
  localparam logic [1:0] WIDTH_WORD = 2'b10;

  // -----------------------------------------------------------------------
  // set_associative_cache instance and its RAM-side handshake.
  // -----------------------------------------------------------------------
  logic        dc_en;
  logic        dc_we;
  logic [31:0] dc_addr;
  logic [31:0] dc_wdata;
  logic [31:0] dc_rdata;
  logic        dc_hit;
  logic        dc_miss;

  logic [31:0] ram_rd_addr;
  logic        ram_rd_req;
  logic [31:0] ram_wr_addr;
  logic        ram_wr_req;
  logic [31:0] ram_wr_data;
  logic        ram_rd_ack;
  logic        ram_wr_ack;
  logic [31:0] ahb_rdata_word;

  set_associative_cache #(
    .NUM_SETS   (NUM_SETS),
    .NUM_WAYS   (NUM_WAYS),
    .BLOCK_SIZE (32),
    .TAG_SIZE   (TAG_SIZE)
  ) u_cache (
    .clk_i          (clk_i),
    .rst_ni         (rst_ni),
    .en_i           (dc_en),
    .addr_i         (dc_addr),
    .wdata_i        (dc_wdata),
    .we_i           (dc_we),
    .rdata_o        (dc_rdata),
    .hit_o          (dc_hit),
    .miss_o         (dc_miss),
    .RAM_addr_o     (ram_rd_addr),
    .RAM_read_req_o (ram_rd_req),
    .RAM_data_i     (ahb_rdata_word),
    .RAM_read_ack_i (ram_rd_ack),
    .RAM_wr_addr_o  (ram_wr_addr),
    .RAM_wr_req_o   (ram_wr_req),
    .RAM_wr_data_o  (ram_wr_data),
    .RAM_wr_ack_i   (ram_wr_ack)
  );

  // Cache is busy servicing a miss refill or a dirty-line write-back
  // whenever either RAM request line is active.
  logic ram_busy;
  assign ram_busy = ram_rd_req | ram_wr_req;

  // -----------------------------------------------------------------------
  // AHB-Lite read/write master: services whichever of RAM_read_req_o /
  // RAM_wr_req_o is currently active. The cache never asserts both at the
  // same time, so a single-outstanding-transfer master is sufficient.
  // -----------------------------------------------------------------------
  logic [31:0] ahb_haddr_q;
  logic [1:0]  ahb_htrans_q;
  logic        ahb_hwrite_q;
  logic [31:0] ahb_hwdata_word_q;
  logic        ahb_busy_q;

  assign ahb_haddr_o  = ahb_haddr_q;
  assign ahb_htrans_o = ahb_htrans_q;
  assign ahb_hwrite_o = ahb_hwrite_q;
  assign ahb_hsize_o  = HSIZE_LINE;

  function automatic logic [31:0] select_line_word(
    input logic [LINE_LENGHT-1:0] line_data,
    input logic [31:0]            addr
  );
    logic [31:0] result;
    int          idx;
    begin
      idx = addr[$clog2(LINE_WORDS)+1:2];
      result = line_data[(idx+1)*32-1 -: 32];
      select_line_word = result;
    end
  endfunction

  function automatic logic [LINE_LENGHT-1:0] place_line_word(
    input logic [31:0] word_data,
    input logic [31:0] addr
  );
    logic [LINE_LENGHT-1:0] result;
    int                     idx;
    begin
      result = '0;
      idx = addr[$clog2(LINE_WORDS)+1:2];
      result[(idx+1)*32-1 -: 32] = word_data;
      place_line_word = result;
    end
  endfunction

  assign ahb_hwdata_o  = place_line_word(ahb_hwdata_word_q, ahb_haddr_q);
  assign ahb_rdata_word = select_line_word(ahb_hrdata_i, ahb_haddr_q);

  // Acks are combinational so they land in the same cycle as ahb_hready_i,
  // matching the cycle in which the cache samples RAM_data_i/RAM_read_ack_i.
  assign ram_rd_ack = ahb_busy_q & ahb_hready_i & ~ahb_hwrite_q;
  assign ram_wr_ack = ahb_busy_q & ahb_hready_i &  ahb_hwrite_q;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      ahb_haddr_q  <= 32'h0000_0000;
      ahb_htrans_q <= HTRANS_IDLE;
      ahb_hwrite_q <= 1'b0;
      ahb_hwdata_word_q <= 32'h0000_0000;
      ahb_busy_q   <= 1'b0;
    end else if (!ahb_busy_q) begin
      if (ram_rd_req) begin
        ahb_busy_q   <= 1'b1;
        ahb_haddr_q  <= ram_rd_addr;
        ahb_htrans_q <= HTRANS_NONSEQ;
        ahb_hwrite_q <= 1'b0;
      end else if (ram_wr_req) begin
        ahb_busy_q   <= 1'b1;
        ahb_haddr_q  <= ram_wr_addr;
        ahb_htrans_q <= HTRANS_NONSEQ;
        ahb_hwrite_q <= 1'b1;
        ahb_hwdata_word_q <= ram_wr_data;
      end else begin
        ahb_htrans_q <= HTRANS_IDLE;
      end
    end else if (ahb_hready_i) begin
      // Data phase completes this cycle (ack pulses combinationally above);
      // go back to idle and wait for the next RAM request, if any.
      ahb_busy_q   <= 1'b0;
      ahb_htrans_q <= HTRANS_IDLE;
    end
    // else: wait state (ahb_hready_i == 0): HADDR/HTRANS/HWRITE/HWDATA held
    // stable by simply not being reassigned.
  end

  // -----------------------------------------------------------------------
  // Width extraction (loads) and merge (partial stores) helper functions.
  // Mirrors the byte/halfword handling already used by riscv_dmem.
  // -----------------------------------------------------------------------
  function automatic logic [31:0] extract_width(
    input logic [31:0] word,
    input logic [1:0]  width,
    input logic        sign_ext,
    input logic [1:0]  byte_off
  );
    logic [31:0] result;
    begin
      unique case (width)
        WIDTH_BYTE: begin
          case (byte_off)
            2'b00: result = sign_ext ? {{24{word[7]}},  word[7:0]}   : {24'h0, word[7:0]};
            2'b01: result = sign_ext ? {{24{word[15]}}, word[15:8]}  : {24'h0, word[15:8]};
            2'b10: result = sign_ext ? {{24{word[23]}}, word[23:16]} : {24'h0, word[23:16]};
            2'b11: result = sign_ext ? {{24{word[31]}}, word[31:24]} : {24'h0, word[31:24]};
          endcase
        end
        WIDTH_HALF: begin
          case (byte_off[1])
            1'b0: result = sign_ext ? {{16{word[15]}}, word[15:0]}  : {16'h0, word[15:0]};
            1'b1: result = sign_ext ? {{16{word[31]}}, word[31:16]} : {16'h0, word[31:16]};
          endcase
        end
        default: result = word; // WIDTH_WORD
      endcase
      extract_width = result;
    end
  endfunction

  function automatic logic [31:0] merge_width(
    input logic [31:0] old_word,
    input logic [31:0] new_payload,
    input logic [1:0]  width,
    input logic [1:0]  byte_off
  );
    logic [31:0] result;
    begin
      result = old_word;
      unique case (width)
        WIDTH_BYTE: begin
          case (byte_off)
            2'b00: result[7:0]   = new_payload[7:0];
            2'b01: result[15:8]  = new_payload[7:0];
            2'b10: result[23:16] = new_payload[7:0];
            2'b11: result[31:24] = new_payload[7:0];
          endcase
        end
        WIDTH_HALF: begin
          case (byte_off[1])
            1'b0: result[15:0]  = new_payload[15:0];
            1'b1: result[31:16] = new_payload[15:0];
          endcase
        end
        default: result = new_payload; // WIDTH_WORD (not used on this path)
      endcase
      merge_width = result;
    end
  endfunction

  // -----------------------------------------------------------------------
  // Top-level access controller: dispatches loads, full-word stores, and
  // read-modify-write partial stores, waiting for RAM quiescence between
  // phases (see header note on why a fixed "done" signal is not available).
  //
  // ST_DONE_A / ST_DONE_B ("handoff buffer" cycles) -- why they exist:
  // req_i/addr_i/we_i/... are driven by the ID/EX stage's OWN output
  // registers, which this controller's stall_o holds frozen for the whole
  // access (so load_valid/rd stay correctly associated with the in-flight
  // instruction until WB consumes them). Freezing is a registered effect:
  // ID/EX only produces a fresh req_i one full cycle after stall_o first
  // drops. If ST_IDLE re-checked req_i immediately when the access settles,
  // it would still see the OLD (stale) request and re-dispatch the exact
  // same, already-completed transaction forever (a livelock), or -- if
  // stall_o dropped even one cycle earlier -- ID/EX could overwrite its
  // registers before WB samples them (data corruption). ST_DONE_A keeps
  // stall_o asserted for the settle/rvalid_o cycle itself; ST_DONE_B drops
  // stall_o (letting ID/EX unfreeze) while dcache_ctrl itself still refuses
  // to look at req_i; by the time ST_IDLE is reached, req_i is guaranteed
  // fresh. Cost: a few extra fixed-latency cycles per access, traded for a
  // provably correct, simple handshake with no assumptions on cache timing.
  // -----------------------------------------------------------------------
  typedef enum logic [2:0] {
    ST_IDLE,
    ST_LOAD,
    ST_RMW_READ,
    ST_STORE,
    ST_DONE_A,
    ST_DONE_B
  } dc_state_e;

  dc_state_e   dc_state_q;
  logic [31:0] req_addr_q;
  logic [1:0]  req_width_q;
  logic        req_sign_ext_q;
  logic [31:0] store_wdata_q;   // raw payload (RMW) or final word to commit (store)
  logic [1:0]  quiet_cnt_q;
  logic        miss_occurred_q;
  logic [31:0] refill_word_q;   // word captured directly from the AHB read data phase

  // Drive the cache from the currently active phase.
  always_comb begin
    dc_en    = 1'b0;
    dc_we    = 1'b0;
    dc_addr  = req_addr_q;
    dc_wdata = store_wdata_q;

    unique case (dc_state_q)
      ST_LOAD, ST_RMW_READ: begin
        dc_en = 1'b1;
        dc_we = 1'b0;
      end
      ST_STORE: begin
        dc_en = 1'b1;
        dc_we = 1'b1;
      end
      default: begin // ST_IDLE, ST_DONE_A, ST_DONE_B: nothing to drive into the cache
      end
    endcase
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      dc_state_q      <= ST_IDLE;
      req_addr_q      <= 32'h0000_0000;
      req_width_q     <= WIDTH_WORD;
      req_sign_ext_q  <= 1'b0;
      store_wdata_q   <= 32'h0000_0000;
      quiet_cnt_q     <= 2'd0;
      miss_occurred_q <= 1'b0;
      refill_word_q   <= 32'h0000_0000;
      rdata_o         <= 32'h0000_0000;
      rvalid_o        <= 1'b0;
    end else begin
      rvalid_o <= 1'b0; // default: 1-cycle completion pulse

      // Capture the AHB read data the instant it is acked, regardless of
      // which phase is active (harmless when not on a read phase).
      if (ram_rd_ack) begin
        refill_word_q <= ahb_rdata_word;
      end

      unique case (dc_state_q)
        ST_IDLE: begin
          quiet_cnt_q     <= 2'd0;
          miss_occurred_q <= 1'b0;
          if (req_i) begin
            req_addr_q     <= addr_i;
            req_width_q    <= width_i;
            req_sign_ext_q <= sign_ext_i;
            if (we_i) begin
              store_wdata_q <= wdata_i;
              dc_state_q    <= (width_i == WIDTH_WORD) ? ST_STORE : ST_RMW_READ;
            end else begin
              dc_state_q <= ST_LOAD;
            end
          end
        end

        ST_LOAD: begin
          if (ram_busy) begin
            quiet_cnt_q     <= 2'd0;
            miss_occurred_q <= 1'b1;
          end else if (quiet_cnt_q != 2'd2) begin
            quiet_cnt_q <= quiet_cnt_q + 2'd1;
          end else begin
            rdata_o    <= extract_width(miss_occurred_q ? refill_word_q : dc_rdata,
                                         req_width_q, req_sign_ext_q, req_addr_q[1:0]);
            rvalid_o   <= 1'b1;
            dc_state_q <= ST_DONE_A;
          end
        end

        ST_RMW_READ: begin
          if (ram_busy) begin
            quiet_cnt_q     <= 2'd0;
            miss_occurred_q <= 1'b1;
          end else if (quiet_cnt_q != 2'd2) begin
            quiet_cnt_q <= quiet_cnt_q + 2'd1;
          end else begin
            store_wdata_q   <= merge_width(miss_occurred_q ? refill_word_q : dc_rdata,
                                            store_wdata_q, req_width_q, req_addr_q[1:0]);
            quiet_cnt_q     <= 2'd0;
            miss_occurred_q <= 1'b0;
            dc_state_q      <= ST_STORE;
          end
        end

        ST_STORE: begin
          if (ram_busy) begin
            quiet_cnt_q <= 2'd0;
          end else if (quiet_cnt_q != 2'd2) begin
            quiet_cnt_q <= quiet_cnt_q + 2'd1;
          end else begin
            rvalid_o   <= 1'b1;
            dc_state_q <= ST_DONE_A;
          end
        end

        ST_DONE_A: begin
          // rvalid_o/rdata_o were valid during the previous cycle's settle;
          // WB has now had a chance to sample them while ID/EX was still
          // frozen. Move to the second handoff cycle (stall_o already low
          // from here on, see assign below) without touching req_i yet.
          dc_state_q <= ST_DONE_B;
        end

        ST_DONE_B: begin
          // ID/EX has been unfrozen for one full cycle by now, so whatever
          // it presents on req_i/addr_i/... at this point is guaranteed to
          // be its freshly decoded (possibly new) request, not a stale
          // leftover from the instruction we just finished servicing.
          dc_state_q <= ST_IDLE;
        end

        default: dc_state_q <= ST_IDLE;
      endcase
    end
  end

  // stall_o must stay high through ST_DONE_A (the cycle rvalid_o/rdata_o are
  // delivered) and drop starting ST_DONE_B, so that ID/EX only unfreezes
  // once WB has safely consumed the completed access. See the FSM comment
  // above for why ST_DONE_A/ST_DONE_B exist instead of returning to ST_IDLE
  // directly.
  assign stall_o = (dc_state_q == ST_LOAD)     |
                   (dc_state_q == ST_RMW_READ) |
                   (dc_state_q == ST_STORE)    |
                   (dc_state_q == ST_DONE_A);

endmodule
