// -----------------------------------------------------------------------------
// Module      : cdc_sync_2ff
// File        : cdc_sync_2ff.sv
// Author      : spt9pad
// Date        : 2026-07-27
// Version     : v1.0
//
// Functionality
// - Generic 2-flip-flop synchronizer for single-bit or multi-bit level signals
//   crossing from one clock domain to another.
// - First FF (meta_q) resolves metastability; second FF (sync_q) is the
//   stable output in the destination domain.
// - In implementation, meta_q and sync_q must be placed as adjacent FFs
//   (add a CDC constraint directive for the target tool, e.g.:
//     Cadence JasperGold/Conformal: set_cdc_synchronizer -type 2ff ...
//     Synopsys SpyGlass: waive CDC ...
//   )
// -----------------------------------------------------------------------------
module cdc_sync_2ff #(
  parameter int W = 1
) (
  input  logic         clk_dst_i,
  input  logic         rst_dst_ni,
  input  logic [W-1:0] data_i,
  output logic [W-1:0] data_o
);

  // First FF: metastability capture stage (may resolve to any value, DO NOT USE).
  // Second FF: stable output in destination clock domain.
  logic [W-1:0] meta_q;
  logic [W-1:0] sync_q;

  always_ff @(posedge clk_dst_i or negedge rst_dst_ni) begin
    if (!rst_dst_ni) begin
      meta_q <= '0;
      sync_q <= '0;
    end else begin
      meta_q <= data_i;
      sync_q <= meta_q;
    end
  end

  assign data_o = sync_q;

endmodule
