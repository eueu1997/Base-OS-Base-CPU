// -----------------------------------------------------------------------------
// Module      : memory_wrapper
// File        : memory_wrapper.sv
// Author      : spt9pad
// Date        : 2026-07-27
// Version     : v2.0
//
// Functionality
// - Instantiates set_associative_cache (CPU clock) and ram (RAM clock).
// - CDC bridge implements a 4-phase level handshake on the read-miss path.
//   Control signals synchronized via cdc_sync_2ff (2-FF synchronizer).
//   Data delivered to cache via the sync'd-strobe pattern (stable before ack).
// - Write-through path structurally present; stubs tied to 0 pending cache
//   implementation. CDC mirrors the read path when implemented.
//
// CDC read path (4-phase level handshake):
//   Phase 1 | CPU  : cache asserts read_req (level), holds addr stable.
//   Phase 2 | RAM  : req synced (2-FF). Rising edge detected; addr captured;
//                    RAM triggered 1 cycle later (addr_ram_q stable).
//   Phase 3 | RAM  : RAM completes; ack_level_ram_q set (held until req falls).
//   Phase 4 | CPU  : ack synced (2-FF). Rising edge -> 1-cycle pulse to cache.
//                    Cache deasserts req; RAM domain clears ack; handshake done.
//
// Data path:
//   ram_rdata_ram_s is stable >= 2 RAM cycles before synced ack reaches CPU.
//   CPU captures it directly using the sync'd rising-edge strobe (safe).
// -----------------------------------------------------------------------------
module memory_wrapper #(
  parameter int NUM_SETS   = 8,
  parameter int NUM_WAYS   = 4,
  parameter int BLOCK_SIZE = 32,
  parameter int TAG_SIZE   = 27,
  parameter int RAM_DEPTH  = 1024
)(
  input  logic                   clk_cpu_i,
  input  logic                   clk_ram_i,
  input  logic                   rst_ni,
  input  logic                   en_i,
  input  logic [31:0]            addr_i,
  input  logic [BLOCK_SIZE-1:0]  wdata_i,
  input  logic                   we_i,
  output logic [BLOCK_SIZE-1:0]  rdata_o,
  output logic                   hit_o,
  output logic                   miss_o
);

  // =========================================================================
  // Cache <-> CDC internal wires
  // =========================================================================
  logic [31:0]           cache_ram_addr_s;
  logic                  cache_ram_read_req_s;
  logic [BLOCK_SIZE-1:0] ram_cache_rdata_s;
  logic                  ram_cache_read_ack_s;

  // Write-through stub (not yet driven by cache).
  logic                  cache_ram_write_req_s;
  logic [31:0]           cache_ram_waddr_s;
  logic [BLOCK_SIZE-1:0] cache_ram_wdata_s;
  logic                  ram_cache_write_ack_s;

  assign cache_ram_write_req_s = 1'b0;
  assign cache_ram_waddr_s     = '0;
  assign cache_ram_wdata_s     = '0;

  // =========================================================================
  // Cache instance (CPU clock domain)
  // =========================================================================
  set_associative_cache #(
    .NUM_SETS   (NUM_SETS),
    .NUM_WAYS   (NUM_WAYS),
    .BLOCK_SIZE (BLOCK_SIZE),
    .TAG_SIZE   (TAG_SIZE)
  ) u_cache (
    .clk_i         (clk_cpu_i),
    .rst_ni        (rst_ni),
    .en_i          (en_i),
    .addr_i        (addr_i),
    .wdata_i       (wdata_i),
    .we_i          (we_i),
    .rdata_o       (rdata_o),
    .hit_o         (hit_o),
    .miss_o        (miss_o),
    .RAM_addr_o    (cache_ram_addr_s),
    .RAM_read_req_o(cache_ram_read_req_s),
    .RAM_data_i    (ram_cache_rdata_s),
    .RAM_read_ack_i(ram_cache_read_ack_s)
  );

  // =========================================================================
  // CDC Bridge: read path (CPU domain -> RAM domain -> CPU domain)
  // =========================================================================

  // --- Phase 1-2: synchronize req level into RAM domain ---
  logic read_req_synced_ram_s;

  cdc_sync_2ff #(.W(1)) u_sync_read_req (
    .clk_dst_i  (clk_ram_i),
    .rst_dst_ni (rst_ni),
    .data_i     (cache_ram_read_req_s),
    .data_o     (read_req_synced_ram_s)
  );

  // Rising-edge detection in RAM domain.
  // Addr captured on rising edge; RAM triggered 1 cycle later so addr_ram_q
  // is already stable (registered) when the RAM sees read_req_ram_dly_q.
  logic        read_req_ram_prev_q;
  logic        read_req_rise_ram_s;
  logic        read_req_ram_dly_q;
  logic [31:0] addr_ram_q;

  always_ff @(posedge clk_ram_i or negedge rst_ni) begin
    if (!rst_ni) begin
      read_req_ram_prev_q <= 1'b0;
      read_req_ram_dly_q  <= 1'b0;
      addr_ram_q          <= '0;
    end else begin
      read_req_ram_prev_q <= read_req_synced_ram_s;
      read_req_ram_dly_q  <= read_req_rise_ram_s;
      if (read_req_rise_ram_s) begin
        // CDC waiver: cache_ram_addr_s is in CPU domain but is guaranteed stable
        // throughout the entire read_miss transaction (cache FSM holds addr_i constant
        // in read_miss state until RAM_read_ack_i is received). The capture happens
        // 2 RAM cycles after req rises; addr has been stable for much longer.
        // Annotate with: set_false_path -from [get_cells u_cache/addr_i_reg*] -to addr_ram_q_reg*
        addr_ram_q <= cache_ram_addr_s;
      end
    end
  end

  assign read_req_rise_ram_s = read_req_synced_ram_s & ~read_req_ram_prev_q;

  // --- Phase 3: level ack in RAM domain ---
  // Held high from RAM completion until req deasserts (completes handshake).
  logic                  ram_read_ack_pulse_s;
  logic [BLOCK_SIZE-1:0] ram_rdata_ram_s;
  logic                  ack_level_ram_q;

  always_ff @(posedge clk_ram_i or negedge rst_ni) begin
    if (!rst_ni) begin
      ack_level_ram_q <= 1'b0;
    end else begin
      if (ram_read_ack_pulse_s) begin
        ack_level_ram_q <= 1'b1;          // set: RAM completed read
      end else if (~read_req_synced_ram_s) begin
        ack_level_ram_q <= 1'b0;          // clear: req deasserted, handshake done
      end
    end
  end

  // --- Phase 4: synchronize ack level into CPU domain ---
  logic read_ack_synced_cpu_s;

  cdc_sync_2ff #(.W(1)) u_sync_read_ack (
    .clk_dst_i  (clk_cpu_i),
    .rst_dst_ni (rst_ni),
    .data_i     (ack_level_ram_q),
    .data_o     (read_ack_synced_cpu_s)
  );

  // Rising-edge detection in CPU domain: generate 1-cycle ack pulse to cache.
  logic read_ack_cpu_prev_q;

  always_ff @(posedge clk_cpu_i or negedge rst_ni) begin
    if (!rst_ni) begin
      read_ack_cpu_prev_q <= 1'b0;
    end else begin
      read_ack_cpu_prev_q <= read_ack_synced_cpu_s;
    end
  end

  // 1-cycle ack pulse to cache.
  // rdata is stable >= 2 RAM cycles before ack reaches CPU domain (data-with-valid).
  assign ram_cache_read_ack_s = read_ack_synced_cpu_s & ~read_ack_cpu_prev_q;
  assign ram_cache_rdata_s    = ram_rdata_ram_s;

  // =========================================================================
  // CDC Bridge: write-through path (TODO when cache implements write-through)
  // Same 4-phase structure: sync write_req CPU->RAM, sync write_ack RAM->CPU.
  // =========================================================================

  // =========================================================================
  // RAM instance (RAM clock domain - 133 MHz)
  // =========================================================================
  ram #(
    .DATA_WIDTH (BLOCK_SIZE),
    .ADDR_WIDTH (32),
    .DEPTH      (RAM_DEPTH)
  ) u_ram (
    .clk_i      (clk_ram_i),
    .rst_ni     (rst_ni),
    // Read port: req delayed 1 cycle so addr_ram_q is stable.
    .read_req_i (read_req_ram_dly_q),
    .addr_i     (addr_ram_q),
    .rdata_o    (ram_rdata_ram_s),
    .read_ack_o (ram_read_ack_pulse_s),
    // Write-through stub.
    .write_req_i(cache_ram_write_req_s),
    .waddr_i    (cache_ram_waddr_s),
    .wdata_i    (cache_ram_wdata_s),
    .write_ack_o(ram_cache_write_ack_s)
  );

endmodule
