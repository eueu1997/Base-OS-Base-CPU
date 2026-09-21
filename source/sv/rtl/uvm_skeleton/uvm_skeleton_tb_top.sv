// -----------------------------------------------------------------------------
// Module      : uvm_skeleton_tb_top
// File        : uvm_skeleton_tb_top.sv
// Author      : spt9pad
// Date        : 2026-09-16
// Version     : v1.0
//
// Functionality
// - Top-level testbench module: generates clock/reset, instantiates the
//   virtual interface, binds it to the DUT (not included here), publishes
//   the virtual interface handle through uvm_config_db, and calls run_test().
// - TODO: instantiate the real DUT and connect its ports to `vif`.
// - TODO: pass the test name via +UVM_TESTNAME=<test> on the simulator
//   command line instead of hard-coding it in run_test().
// -----------------------------------------------------------------------------
module uvm_skeleton_tb_top;

  import uvm_pkg::*;
  import uvm_skeleton_pkg::*;

  logic clk;
  logic rst_n;

  // Clock generation.
  initial clk = 1'b0;
  always #5 clk = ~clk;

  // Reset generation.
  initial begin
    rst_n = 1'b0;
    repeat (4) @(posedge clk);
    rst_n = 1'b1;
  end

  uvm_skeleton_if vif (.clk(clk), .rst_n(rst_n));


  ahb_lite_2slave_dut u_dut (
    .clk_i          (clk),
    .rst_ni         (rst_n),
    .haddr_i        (vif.haddr),
    .htrans_i       (vif.htrans),
    .hwrite_i       (vif.hwrite),
    .hsize_i        (vif.hsize),
    .hwdata_i       (vif.hwdata),
    .hrdata_o       (vif.hrdata),
    .hready_o       (vif.hready),
    .hresp_o        (vif.hresp),
    .slave0_sel_o   (vif.slave0_sel),
    .slave1_sel_o   (vif.slave1_sel)
  );

  initial begin
    // declare virtual interface in uvm_config_db
    uvm_config_db#(virtual uvm_skeleton_if.master)::set(null, "*", "vif", vif);
    uvm_config_db#(virtual uvm_skeleton_if.monitor)::set(null, "*", "vif", vif);

    run_test("uvm_skeleton_test");
  end

endmodule
