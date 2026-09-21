// -----------------------------------------------------------------------------
// Interface   : uvm_skeleton_if
// File        : uvm_skeleton_if.sv
// Author      : spt9pad
// Date        : 2026-09-16
// Version     : v1.0
//
// Functionality
// - Placeholder pin-level interface between the testbench and the DUT.
// - Replace the generic signals below with the real DUT port list
//   (e.g. address/data/control signals, handshake signals, etc.).
// - Two clocking blocks / modports are sketched out (driver, monitor) so the
//   driver only drives what it owns and the monitor only samples.
// -----------------------------------------------------------------------------
interface uvm_skeleton_if (input logic clk, input logic rst_n);


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
