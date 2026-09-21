// -----------------------------------------------------------------------------
// Module      : ahb_lite_2slave_dut
// File        : ahb_lite_2slave_dut.sv
// Author      : spt9pad
// Date        : 2026-09-14
// Version     : v1.0
//
// Functionality
// - Minimal AHB-Lite interconnect DUT for the UVM interview exercise.
// - Accepts one external AHB-Lite master and routes accesses to two slaves.
// - Slave 0 is mapped at 0x0000_0000-0x0000_0FFF.
// - Slave 1 is mapped at 0x0001_0000-0x0001_0FFF.
// - Both internal slaves are zero-wait-state word memories.
// - Unmapped accesses return an AHB-Lite ERROR response.
// -----------------------------------------------------------------------------
module ahb_lite_2slave_dut #(
  parameter int ADDRESS_WIDTH = 32,
  parameter int DATA_WIDTH    = 32,
  parameter int SLAVE_WORDS   = 1024
) (
  input  logic                  clk_i,
  input  logic                  rst_ni,

  input  logic [ADDRESS_WIDTH-1:0] haddr_i,
  input  logic [1:0]               htrans_i,
  input  logic                     hwrite_i,
  input  logic [2:0]               hsize_i,
  input  logic [DATA_WIDTH-1:0]    hwdata_i,
  output logic [DATA_WIDTH-1:0]    hrdata_o,
  output logic                     hready_o,
  output logic                     hresp_o,

  output logic                     slave0_sel_o,
  output logic                     slave1_sel_o
);

  localparam logic [1:0] HTRANS_IDLE   = 2'b00;
  localparam logic [1:0] HTRANS_BUSY   = 2'b01;
  localparam logic [1:0] HTRANS_NONSEQ = 2'b10;
  localparam logic [1:0] HTRANS_SEQ    = 2'b11;
  localparam logic [31:0] SLAVE0_BASE  = 32'h0000_0000;
  localparam logic [31:0] SLAVE1_BASE  = 32'h0001_0000;
  localparam logic [31:0] SLAVE_MASK   = 32'hFFFF_F000;

  logic [DATA_WIDTH-1:0] slave0_mem [0:SLAVE_WORDS-1];
  logic [DATA_WIDTH-1:0] slave1_mem [0:SLAVE_WORDS-1];

  logic                  request_valid;
  logic                  request_aligned;
  logic                  request_slave0;
  logic                  request_slave1;
  logic [DATA_WIDTH-1:0] response_data_q;
  logic                  response_error_q;
  logic [ADDRESS_WIDTH-1:0] response_addr_q;
  logic [2:0]            response_size_q;
  logic                  unused_response_fields;

ahb_slave #(
  .BASE_ADDR(SLAVE0_BASE)
) u_slave0 (
  .clk_i(clk_i),
  .rst_ni(rst_ni),
  .haddr_i(haddr_i),
  .htrans_i(htrans_i),
  .hwrite_i(hwrite_i),
  .hsize_i(hsize_i),
  .hwdata_i(hwdata_i),
  .hrdata_o(),
  .hready_o(),
  .hresp_o()
);
ahb_slave #(
  .BASE_ADDR(SLAVE1_BASE)
) u_slave1 (
  .clk_i(clk_i),
  .rst_ni(rst_ni),
  .haddr_i(haddr_i),
  .htrans_i(htrans_i),
  .hwrite_i(hwrite_i),
  .hsize_i(hsize_i),
  .hwdata_i(hwdata_i),
  .hrdata_o(),
  .hready_o(),
  .hresp_o()
);
endmodule