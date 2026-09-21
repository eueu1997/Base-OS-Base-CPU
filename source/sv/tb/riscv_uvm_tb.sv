`timescale 1ns/1ps
module riscv_uvm_tb;
  import uvm_pkg::*;
  import riscv_uvm_pkg::*;

  localparam int LINE_BITS = 256;
  logic clk_i;
  logic rst_ni;
  riscv_uvm_if imem_if(clk_i, rst_ni);
  riscv_uvm_if dmem_if(clk_i, rst_ni);
  riscv_status_if status_if(clk_i);
  riscv_mem_if #(.MEM_WORDS(1024)) mem_if();
  // Reference model's own private memory copy, kept independent from the
  // DUT-visible mem_if so the end-of-test compare is meaningful.
  riscv_mem_if #(.MEM_WORDS(1024)) model_mem_if();
  riscv_ref_model_if ref_model_if(clk_i, rst_ni);

  riscv u_dut (
    .clk_i(clk_i), .rst_ni(rst_ni), .illegal_instr_o(status_if.illegal_instr),
    .ahb_haddr_o(imem_if.haddr), .ahb_htrans_o(imem_if.htrans),
    .ahb_hwrite_o(imem_if.hwrite), .ahb_hsize_o(imem_if.hsize),
    .ahb_hrdata_i(imem_if.hrdata), .ahb_hready_i(imem_if.hready), .ahb_hresp_i(imem_if.hresp),
    .dahb_haddr_o(dmem_if.haddr), .dahb_htrans_o(dmem_if.htrans),
    .dahb_hwrite_o(dmem_if.hwrite), .dahb_hsize_o(dmem_if.hsize),
    .dahb_hwdata_o(dmem_if.hwdata), .dahb_hrdata_i(dmem_if.hrdata),
    .dahb_hready_i(dmem_if.hready), .dahb_hresp_i(dmem_if.hresp)
  );

  // Golden ISA reference model, fed with fetched instructions by
  // riscv_ref_model_monitor (see riscv_uvm_pkg.sv).
  riscv_isa_ref_model u_ref_model (
    .clk_i          (clk_i),
    .rst_ni         (rst_ni),
    .instr_valid_i  (ref_model_if.instr_valid),
    .instr_i        (ref_model_if.instr),
    .pc_o           (ref_model_if.pc),
    .pc_next_o      (ref_model_if.pc_next),
    .illegal_instr_o(ref_model_if.illegal_instr),
    .rf_we_o        (ref_model_if.rf_we),
    .rf_waddr_o     (ref_model_if.rf_waddr),
    .rf_wdata_o     (ref_model_if.rf_wdata),
    .mem_req_o      (ref_model_if.mem_req),
    .mem_we_o       (ref_model_if.mem_we),
    .mem_addr_o     (ref_model_if.mem_addr),
    .mem_width_o    (ref_model_if.mem_width),
    .mem_sign_ext_o (ref_model_if.mem_sign_ext),
    .mem_wdata_o    (ref_model_if.mem_wdata),
    .mem_rdata_i    (ref_model_if.mem_rdata)
  );

  // Word-aligned functional read for the reference model's loads, served
  // from the model's own memory copy (not the DUT-visible mem_if).
  assign ref_model_if.mem_rdata = model_mem_if.mem[ref_model_if.mem_addr[31:2]];

  // Width-aware read-modify-write merge for the model's own stores, mirroring
  // what riscv_dcache_ctrl does for the DUT before issuing a full-word write.
  logic [31:0] model_store_word;
  always_comb begin
    model_store_word = model_mem_if.mem[ref_model_if.mem_addr[31:2]];
    unique case (ref_model_if.mem_width)
      2'b00:   model_store_word[8*ref_model_if.mem_addr[1:0] +: 8]  = ref_model_if.mem_wdata[7:0];
      2'b01:   model_store_word[16*ref_model_if.mem_addr[1] +: 16] = ref_model_if.mem_wdata[15:0];
      default: model_store_word = ref_model_if.mem_wdata;
    endcase
  end

  always_ff @(posedge clk_i) begin
    if (rst_ni && ref_model_if.mem_req && ref_model_if.mem_we)
      model_mem_if.mem[ref_model_if.mem_addr[31:2]] <= model_store_word;
  end

  assign status_if.x1 = u_dut.u_regfile.rf_q[1];
  assign status_if.x2 = u_dut.u_regfile.rf_q[2];
  assign status_if.x3 = u_dut.u_regfile.rf_q[3];
  assign status_if.x4 = u_dut.u_regfile.rf_q[4];
  assign status_if.x5 = u_dut.u_regfile.rf_q[5];
  assign status_if.mem0 = mem_if.mem[0];

  // Full register-file comparison arrays for the smoke test's end-of-run check.
  always_comb begin
    for (int i = 0; i < 32; i++) begin
      status_if.dut_rf[i]   = u_dut.u_regfile.rf_q[i];
      status_if.model_rf[i] = u_ref_model.rf_q[i];
    end
  end

  always_comb begin
    imem_if.hready = 1'b1;
    imem_if.hresp = 1'b0;
    imem_if.hrdata = '0;
    for (int word = 0; word < 8; word++)
      imem_if.hrdata[word*32 +: 32] = mem_if.mem[(imem_if.haddr[31:5] * 8) + word];
    dmem_if.hready = 1'b1;
    dmem_if.hresp = 1'b0;
    dmem_if.hrdata = '0;
    for (int word = 0; word < 8; word++)
      dmem_if.hrdata[word*32 +: 32] = mem_if.mem[(dmem_if.haddr[31:5] * 8) + word];
  end

  always_ff @(posedge clk_i) begin
    if (rst_ni && dmem_if.hready && dmem_if.htrans[1] && dmem_if.hwrite) begin
      mem_if.mem[(dmem_if.haddr[31:2])] = dmem_if.hwdata[dmem_if.haddr[4:2]*32 +: 32];
    end
  end

  initial begin
    // Default fill only: the test case selects the actual program via
    // mem_vif.preload()/model_mem_vif.preload() (see riscv_smoke_test and
    // riscv_asm helpers).
    mem_if.clear();
    model_mem_if.clear();
  end

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
    uvm_config_db#(virtual riscv_uvm_if)::set(null, "uvm_test_top.env.imem_monitor", "vif", imem_if);
    uvm_config_db#(virtual riscv_uvm_if)::set(null, "uvm_test_top.env.dmem_monitor", "vif", dmem_if);
    uvm_config_db#(virtual riscv_uvm_if)::set(null, "uvm_test_top.env.ref_monitor", "imem_vif", imem_if);
    uvm_config_db#(virtual riscv_ref_model_if)::set(null, "uvm_test_top.env.ref_monitor", "ref_vif", ref_model_if);
    uvm_config_db#(virtual riscv_status_if)::set(null, "uvm_test_top", "status_vif", status_if);
    uvm_config_db#(virtual riscv_mem_if)::set(null, "uvm_test_top", "mem_vif", mem_if);
    uvm_config_db#(virtual riscv_mem_if)::set(null, "uvm_test_top", "model_mem_vif", model_mem_if);
    run_test("riscv_smoke_test");
  end
endmodule