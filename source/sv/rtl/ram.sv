// -----------------------------------------------------------------------------
// Module      : ram
// File        : ram.sv
// Author      : spt9pad
// Date        : 2026-07-27
// Version     : v1.0
//
// Functionality
// - Behavioral synchronous RAM, word-aligned 32-bit access.
// - Clocked by clk_i (intended for 133 MHz RAM clock domain).
// - Read: 1-cycle latency; read_ack_o is asserted the cycle after read_req_i.
// - Write: 1-cycle latency; write_ack_o is asserted the cycle after write_req_i.
// - Address is byte-addressed; bits [1:0] are ignored (word granularity).
// -----------------------------------------------------------------------------
module ram #(
  parameter int DATA_WIDTH = 32,
  parameter int ADDR_WIDTH = 32,
  parameter int DEPTH      = 1024
)(
  input  logic                   clk_i,
  input  logic                   rst_ni,
  // Read port
  input  logic                   read_req_i,
  input  logic [ADDR_WIDTH-1:0]  addr_i,
  output logic [DATA_WIDTH-1:0]  rdata_o,
  output logic                   read_ack_o,
  // Write port (write-through from cache, not yet driven)
  input  logic                   write_req_i,
  input  logic [ADDR_WIDTH-1:0]  waddr_i,
  input  logic [DATA_WIDTH-1:0]  wdata_i,
  output logic                   write_ack_o
);

  localparam int IDX_W = $clog2(DEPTH);

  logic [DATA_WIDTH-1:0] mem [DEPTH-1:0];

  // Read: sample address, return data and ack on next rising edge.
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      rdata_o    <= '0;
      read_ack_o <= 1'b0;
    end else begin
      read_ack_o <= read_req_i;
      if (read_req_i) begin
        rdata_o <= mem[addr_i[IDX_W+1:2]];
      end
    end
  end

  // Write: update memory and ack on next rising edge.
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      write_ack_o <= 1'b0;
    end else begin
      write_ack_o <= write_req_i;
      if (write_req_i) begin
        mem[waddr_i[IDX_W+1:2]] <= wdata_i;
      end
    end
  end

endmodule
