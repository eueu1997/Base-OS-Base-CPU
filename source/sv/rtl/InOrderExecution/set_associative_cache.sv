// -----------------------------------------------------------------------------
// Module      : set_associative_cache
// File        : set_associative_cache.sv
// Author      : spt9pad
// Date        : 2026-07-23
// Version     : v1.0
//
// Functionality
// - Top-level wrapper that instantiates NUM_SETS cache_set modules.
// - Address bits [4:2] select and enable one set.
// - Input to each set is packed as {tag, data}.
// - Output to CPU is only data payload (BLOCK_SIZE-1:0).
// - Replace policy is intentionally not implemented in this step.
// -----------------------------------------------------------------------------
module set_associative_cache #(
  parameter int NUM_SETS   = 8,
  parameter int NUM_WAYS   = 4,
  parameter int BLOCK_SIZE = 32,
  parameter int TAG_SIZE   = 27
)(
  input  logic                  clk_i,
  input  logic                  rst_ni,
  input  logic                  en_i,
  input  logic [31:0]           addr_i,
  input  logic [BLOCK_SIZE-1:0] wdata_i,
  input  logic                  we_i,
  output logic [BLOCK_SIZE-1:0] rdata_o,
  output logic                  hit_o,
  output logic                  miss_o,
  // RAM Access for read miss
  output logic [31:0]           RAM_addr_o,
  output logic                  RAM_read_req_o,
  input  logic [BLOCK_SIZE-1:0] RAM_data_i,
  input  logic                  RAM_read_ack_i,
  // RAM write-back port
  output logic [31:0]           RAM_wr_addr_o,
  output logic                  RAM_wr_req_o,
  output logic [BLOCK_SIZE-1:0] RAM_wr_data_o,
  input  logic                  RAM_wr_ack_i
);

  localparam int SET_IDX_W = $clog2(NUM_SETS);
  localparam int LINE_W    = BLOCK_SIZE + TAG_SIZE;

  logic [SET_IDX_W-1:0] set_idx_s;
  logic [TAG_SIZE-1:0]  tag_s;
  logic [LINE_W-1:0]    data_i_s;
  logic [NUM_SETS-1:0]  set_en_s;
  logic [LINE_W-1:0]    set_data_o_s [NUM_SETS-1:0];
  logic [LINE_W-1:0]    sel_data_o_s;
  logic [NUM_SETS-1:0]  miss_s;
  logic [NUM_SETS-1:0]  hit_s;
  logic                 cache_wb_s;
  logic [NUM_SETS-1:0]                     set_dirty3_s;
  logic [NUM_SETS-1:0][TAG_SIZE-1:0]       set_way3_tag_s;
  logic [NUM_SETS-1:0][BLOCK_SIZE-1:0]     set_way3_data_s;
  logic [NUM_SETS-1:0]                     set_clear_dirty3_s;
  logic                                    sel_dirty3_s;
  logic [TAG_SIZE-1:0]                     sel_way3_tag_s;
  logic [BLOCK_SIZE-1:0]                   sel_way3_data_s;
  logic                                    wb_needed_s;
    // FSM states: read, read miss, write, write miss, writeback.
  typedef  enum logic [2:0] {
    idle,
    read,
    read_miss,
    write,
    write_miss,
    writeback
  } fsm_state_t;

  fsm_state_t fsm_state_s;

  // For 8 sets this is exactly addr_i[4:2].
  assign set_idx_s = addr_i[4:2];
  assign tag_s     = addr_i[31:5];
  assign data_i_s  = {tag_s, wdata_i};

  genvar i;
  generate
    for (i = 0; i < NUM_SETS; i++) begin : g_cache_set
      // Gate cache update: writeback state and writeback-needed both freeze the shift
      // chain so that way3's pre-eviction data is intact when the RAM write fires.
      assign set_en_s[i] = en_i && (set_idx_s == i[SET_IDX_W-1:0]) &&
                           (fsm_state_s != writeback) && !wb_needed_s;

      cache_set #(
        .NUM_SETS   (NUM_SETS),
        .NUM_WAYS   (NUM_WAYS),
        .BLOCK_SIZE (BLOCK_SIZE),
        .TAG_SIZE   (TAG_SIZE)
      ) u_cache_set (
        .clk_i          (clk_i),
        .rst_n_i        (rst_ni),
        .en_i           (set_en_s[i]),
        .we_i           (we_i),
        .data_i         (data_i_s),
        .data_o         (set_data_o_s[i]),
        .miss_o         (miss_s[i]),
        .hit_o          (hit_s[i]),
        .refill_i       (1'b0),
        .clear_dirty3_i (set_clear_dirty3_s[i]),
        .dirty3_o       (set_dirty3_s[i]),
        .way3_tag_o     (set_way3_tag_s[i]),
        .way3_data_o    (set_way3_data_s[i])
      );
    end
  endgenerate

  always_comb begin
    sel_data_o_s = '0;
    for (int j = 0; j < NUM_SETS; j++) begin
      if (set_idx_s == j[SET_IDX_W-1:0]) begin
        sel_data_o_s = set_data_o_s[j];
      end
    end
  end

  assign sel_dirty3_s    = set_dirty3_s[set_idx_s];
  assign sel_way3_tag_s  = set_way3_tag_s[set_idx_s];
  assign sel_way3_data_s = set_way3_data_s[set_idx_s];
  assign wb_needed_s     = en_i && sel_dirty3_s && (sel_way3_tag_s != tag_s);

  assign rdata_o = (cache_wb_s) ? RAM_data_i : sel_data_o_s[BLOCK_SIZE-1:0];
  assign hit_o   = |hit_s;
  assign miss_o  = |miss_s;


  // Clear dirty bit of way3 in selected set when writeback ack is received.
  always_comb begin
    set_clear_dirty3_s = '0;
    if (fsm_state_s == writeback && RAM_wr_ack_i) begin
      set_clear_dirty3_s[set_idx_s] = 1'b1;
    end
  end

  // Combinational outputs driven by FSM state.
  always_comb begin
    RAM_addr_o     = '0;
    RAM_read_req_o = 1'b0;
    cache_wb_s     = 1'b0;
    RAM_wr_addr_o  = '0;
    RAM_wr_req_o   = 1'b0;
    RAM_wr_data_o  = '0;

    unique case (fsm_state_s)
      read: begin
        if (en_i && !we_i && miss_o) begin
          RAM_addr_o = addr_i;
        end
      end
      read_miss: begin
        // Keep address stable and request asserted until ack.
        // TODO: possible CDC if RAM clock is slower than cache clock.
        RAM_addr_o     = addr_i;
        RAM_read_req_o = ~RAM_read_ack_i;
        cache_wb_s     = RAM_read_ack_i;
      end
      writeback: begin
        RAM_wr_req_o  = 1'b1;
        RAM_wr_addr_o = {sel_way3_tag_s, set_idx_s, 2'b00};
        RAM_wr_data_o = sel_way3_data_s;
      end
      default: begin
      end
    endcase
  end

  // Sequential: only FSM state register.
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      fsm_state_s <= idle;
    end else begin
      unique case (fsm_state_s)
        idle: begin
          if (en_i) begin
            if (wb_needed_s) begin
              fsm_state_s <= writeback;
            end else if (we_i) begin
              fsm_state_s <= write;
            end else begin
              fsm_state_s <= read;
            end
          end else begin
            fsm_state_s <= idle;
          end
        end
        read: begin
          if (en_i) begin
            if (wb_needed_s) begin
              fsm_state_s <= writeback;
            end else if (!we_i) begin
              if (miss_o) begin
                fsm_state_s <= read_miss;
              end
            end else begin
              fsm_state_s <= write;
            end
          end
        end
        read_miss: begin
          if (RAM_read_ack_i) begin
            fsm_state_s <= write;
          end
        end
        write: begin
          if (en_i) begin
            if (wb_needed_s) begin
              fsm_state_s <= writeback;
            end else if (we_i) begin
              if (miss_o) begin
                fsm_state_s <= write_miss;
              end
            end else begin
              fsm_state_s <= read;
            end
          end
        end
        write_miss: begin
          fsm_state_s <= read;
        end
        writeback: begin
          if (RAM_wr_ack_i) begin
            fsm_state_s <= idle;  // re-evaluate request after dirty3 cleared
          end
        end
        default: begin
          fsm_state_s <= idle;
        end
      endcase
    end
  end
endmodule