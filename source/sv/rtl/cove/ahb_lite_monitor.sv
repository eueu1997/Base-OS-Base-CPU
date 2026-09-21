class ahb_lite_monitor extends uvm_monitor;
  `uvm_component_utils(ahb_lite_monitor)

  virtual ahb_lite_if.monitor vif;
  uvm_analysis_port #(ahb_lite_item) item_collected_port;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    item_collected_port = new("item_collected_port", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual ahb_lite_if.monitor)::get(this, "", "vif", vif)) begin
      `uvm_fatal("NOVIF", "AHB-Lite monitor virtual interface was not configured")
    end
  endfunction

  task run_phase(uvm_phase phase);
    ahb_lite_item pending_item;
    ahb_lite_item completed_item;
    forever begin
      @(vif.monitor_cb);
      if (pending_item != null) begin
        completed_item = ahb_lite_item::type_id::create("completed_item");
        completed_item.copy(pending_item);
        completed_item.read_data       = vif.monitor_cb.hrdata;
        completed_item.response_error  = vif.monitor_cb.hresp;
        completed_item.slave0_selected = vif.monitor_cb.slave0_sel;
        completed_item.slave1_selected = vif.monitor_cb.slave1_sel;
        item_collected_port.write(completed_item);
        pending_item = null;
      end
      if (vif.monitor_cb.hready && vif.monitor_cb.htrans[1]) begin
        pending_item = ahb_lite_item::type_id::create("pending_item");
        pending_item.address    = vif.monitor_cb.haddr;
        pending_item.trans      = vif.monitor_cb.htrans;
        pending_item.write      = vif.monitor_cb.hwrite;
        pending_item.size       = vif.monitor_cb.hsize;
        pending_item.write_data = vif.monitor_cb.hwdata;
      end
    end
  endtask
endclass