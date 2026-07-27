// -----------------------------------------------------------------------------
// Module      : mem_ref_model
// File        : mem_ref_model.sv
// Author      : spt9pad
// Date        : 2026-07-27
//
// Functionality
// - Behavioral golden model for memory_wrapper.
// - Runs in parallel with the DUT in the testbench.
// - Maintains a flat word-addressable array identical in size to the DUT RAM.
// - Captures writes when the DUT commits them (wr_commit_i pulse).
// - On each read commit (rd_commit_i pulse) it latches the expected data,
//   compares it with the actual DUT output and asserts ref_err_o on mismatch.
// - ref_exp_comb_o is a purely combinatorial view of what the model currently
//   expects for addr_i; useful for real-time waveform inspection.
//
// Timing contract (set by the testbench)
//   wr_commit_i  high for exactly 1 clk_cpu cycle when the DUT asserts hit_o
//                while we_i=1.  addr_i and wdata_i are still stable.
//   rd_commit_i  high for exactly 1 clk_cpu cycle when DUT data is valid
//                (hit_o | cache_wb_s) while we_i=0.  addr_i and dut_rdata_i
//                are stable.
//
// Address indexing: word-aligned, identical to DUT RAM
//   word_idx = addr_i[$clog2(MEM_DEPTH)+1 : 2]
// -----------------------------------------------------------------------------
module mem_ref_model #(
  parameter int DATA_W    = 32,
  parameter int ADDR_W    = 32,
  parameter int MEM_DEPTH = 1024
)(
  input  logic              clk_i,
  input  logic              rst_ni,

  // CPU request bus – same signals as DUT
  input  logic              we_i,
  input  logic [ADDR_W-1:0] addr_i,
  input  logic [DATA_W-1:0] wdata_i,

  // Commit strobes (generated in TB from DUT outputs)
  input  logic              wr_commit_i,   // write accepted by DUT  (hit_o & we_i)
  input  logic              rd_commit_i,   // read data valid from DUT (!we_i & data_valid)

  // DUT output to compare against
  input  logic [DATA_W-1:0] dut_rdata_i,

  // Reference outputs
  output logic [DATA_W-1:0] ref_exp_comb_o, // combinatorial: expected for current addr
  output logic [DATA_W-1:0] ref_rdata_o,    // registered: expected at last rd_commit
  output logic              ref_valid_o,    // 1-cycle pulse when ref_rdata_o updated
  output logic              ref_match_o,    // registered: 1=last read matched, 0=mismatch
  output logic              ref_err_o       // 1-cycle pulse when mismatch detected
);

  localparam int IDX_W = $clog2(MEM_DEPTH);  // = 10 for MEM_DEPTH=1024

  // -------------------------------------------------------------------------
  // Internal memory (word-addressed)
  // -------------------------------------------------------------------------
  logic [DATA_W-1:0] mem_q [MEM_DEPTH];

  // Word-aligned index – mirrors ram.sv: mem[addr_i[IDX_W+1:2]]
  wire [IDX_W-1:0] word_idx = addr_i[IDX_W+1:2];

  // -------------------------------------------------------------------------
  // Combinatorial expected data at the current address (always visible)
  // -------------------------------------------------------------------------
  assign ref_exp_comb_o = mem_q[word_idx];

  // -------------------------------------------------------------------------
  // Sequential logic
  // -------------------------------------------------------------------------
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      // Cache FFs are cleared on reset; RAM contents survive (not a register).
      // Mirror that: keep mem_q intact, reset only the status outputs.
      ref_rdata_o <= '0;
      ref_valid_o <= 1'b0;
      ref_match_o <= 1'b1;
      ref_err_o   <= 1'b0;
    end else begin
      // Defaults: de-assert pulses
      ref_err_o   <= 1'b0;
      ref_valid_o <= 1'b0;

      // -----------------------------------------------------------------
      // Write commit: record what the DUT just wrote to memory/cache
      // -----------------------------------------------------------------
      if (wr_commit_i)
        mem_q[word_idx] <= wdata_i;

      // -----------------------------------------------------------------
      // Read commit: compare DUT output against model and latch result
      // -----------------------------------------------------------------
      if (rd_commit_i) begin
        ref_rdata_o <= ref_exp_comb_o;   // snapshot before any same-cycle write
        ref_valid_o <= 1'b1;
        if (dut_rdata_i !== ref_exp_comb_o) begin
          ref_match_o <= 1'b0;
          ref_err_o   <= 1'b1;
        end else begin
          ref_match_o <= 1'b1;
        end
      end
    end
  end

endmodule
