class ahb_lite_driver extends uvm_driver #(ahb_lite_item);
  `uvm_component_utils(ahb_lite_driver)

  virtual ahb_lite_if.master vif;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual ahb_lite_if.master)::get(this, "", "vif", vif)) begin
      `uvm_fatal("NOVIF", "AHB-Lite master virtual interface was not configured")
    end
  endfunction

  task run_phase(uvm_phase phase);
    ahb_lite_item item;
    drive_idle();
    wait (vif.rst_ni === 1'b1);
    forever begin
      seq_item_port.get_next_item(item);
      @(vif.master_cb);
      vif.master_cb.haddr  <= item.address;
      vif.master_cb.htrans <= item.trans;
      vif.master_cb.hwrite <= item.write;
      vif.master_cb.hsize  <= item.size;
      vif.master_cb.hwdata <= item.write_data;
      @(vif.master_cb);
      while (!vif.master_cb.hready) begin
        @(vif.master_cb);
      end
      drive_idle();
      seq_item_port.item_done();
    end
  endtask

  task drive_idle();
    vif.master_cb.haddr  <= '0;
    vif.master_cb.htrans <= HTRANS_IDLE;
    vif.master_cb.hwrite <= 1'b0;
    vif.master_cb.hsize  <= 3'b010;
    vif.master_cb.hwdata <= '0;
  endtask
endclass