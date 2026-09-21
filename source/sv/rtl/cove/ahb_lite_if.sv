// -----------------------------------------------------------------------------
// Module      : ahb_lite_if
// File        : ahb_lite_if.sv
// Author      : spt9pad
// Date        : 2026-09-14
// Version     : v1.0
//
// Functionality
// - Shared AHB-Lite interface for the two-slave UVM exercise.
// - Provides DUT, master-driver, and monitor modports.
// - Provides clocking blocks for cycle-accurate UVM access.
// -----------------------------------------------------------------------------
interface ahb_lite_if #(
  parameter int ADDRESS_WIDTH = 32,
  parameter int DATA_WIDTH    = 32
) (
  input logic clk_i,
  input logic rst_ni
);

  logic [ADDRESS_WIDTH-1:0] haddr;
  logic [1:0]               htrans;
  logic                     hwrite;
  logic [2:0]               hsize;
  logic [DATA_WIDTH-1:0]    hwdata;
  logic [DATA_WIDTH-1:0]    hrdata;
  logic                     hready;
  logic                     hresp;
  logic                     slave0_sel;
  logic                     slave1_sel;

  clocking master_cb @(posedge clk_i);
    default input #1step output #1step;
    output haddr, htrans, hwrite, hsize, hwdata;
    input  hrdata, hready, hresp, slave0_sel, slave1_sel;
  endclocking

  clocking monitor_cb @(posedge clk_i);
    default input #1step output #1step;
    input haddr, htrans, hwrite, hsize, hwdata;
    input hrdata, hready, hresp, slave0_sel, slave1_sel;
  endclocking

  modport dut (
    input  clk_i,
    input  rst_ni,
    input  haddr,
    input  htrans,
    input  hwrite,
    input  hsize,
    input  hwdata,
    output hrdata,
    output hready,
    output hresp,
    output slave0_sel,
    output slave1_sel
  );

  modport master (
    input  clk_i,
    input  rst_ni,
    clocking master_cb
  );

  modport monitor (
    input  clk_i,
    input  rst_ni,
    clocking monitor_cb
  );

endinterface