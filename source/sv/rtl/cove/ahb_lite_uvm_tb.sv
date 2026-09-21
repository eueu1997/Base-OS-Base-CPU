module ahb_lite_uvm_tb;

  import uvm_pkg::*;
  import ahb_lite_uvm_pkg::*;

  logic clk_i;
  logic rst_ni;

  ahb_lite_if ahb_vif (
    .clk_i  (clk_i),
    .rst_ni (rst_ni)
  );

  ahb_lite_2slave_dut u_dut (
    .clk_i          (clk_i),
    .rst_ni         (rst_ni),
    .haddr_i        (ahb_vif.haddr),
    .htrans_i       (ahb_vif.htrans),
    .hwrite_i       (ahb_vif.hwrite),
    .hsize_i        (ahb_vif.hsize),
    .hwdata_i       (ahb_vif.hwdata),
    .hrdata_o       (ahb_vif.hrdata),
    .hready_o       (ahb_vif.hready),
    .hresp_o        (ahb_vif.hresp),
    .slave0_sel_o   (ahb_vif.slave0_sel),
    .slave1_sel_o   (ahb_vif.slave1_sel)
  );

  initial begin
    clk_i = 1'b0;
    forever #5 clk_i = ~clk_i;
  end

  initial begin
    rst_ni = 1'b0;
    repeat (5) @(posedge clk_i);
    rst_ni = 1'b1;
  end

  initial begin
    uvm_config_db#(virtual ahb_lite_if.master)::set(null,
                                                    "uvm_test_top.env.agent.driver",
                                                    "vif",
                                                    ahb_vif);
    uvm_config_db#(virtual ahb_lite_if.monitor)::set(null,
                                                     "uvm_test_top.env.agent.monitor",
                                                     "vif",
                                                     ahb_vif);
    run_test("ahb_lite_coverage_test");

  end

  property valid_transfer_has_result;
    @(posedge clk_i)
      disable iff (!rst_ni)
      (ahb_vif.htrans[1] && ahb_vif.hready) |->
      (ahb_vif.slave0_sel || ahb_vif.slave1_sel || ahb_vif.hresp);
  endproperty

  assert property (valid_transfer_has_result)
    else $error("AHB transfer has no slave selection and no error response");

  assert property (@(posedge clk_i)
                   disable iff (!rst_ni)
                   !(ahb_vif.slave0_sel && ahb_vif.slave1_sel))
    else $error("Multiple slaves selected simultaneously");


endmodule