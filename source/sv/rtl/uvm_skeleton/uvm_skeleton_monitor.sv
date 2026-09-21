// -----------------------------------------------------------------------------
// Class       : uvm_skeleton_monitor
// File        : uvm_skeleton_monitor.sv
// Author      : spt9pad
// Date        : 2026-09-16
// Version     : v1.0
//
// Functionality
// - Passively samples the virtual interface and reconstructs transactions.
// - Broadcasts observed items on `item_collected_port` to whoever needs them
//   (scoreboard, coverage collector, other checkers).
// - TODO: add protocol checks here (or in a dedicated checker class) instead
//   of only in assertions, if end-to-end sequence checking is needed.
// -----------------------------------------------------------------------------
class uvm_skeleton_monitor extends uvm_monitor;
  `uvm_component_utils(uvm_skeleton_monitor)

  virtual uvm_skeleton_if vif;
  uvm_analysis_port #(uvm_skeleton_item) item_collected_port;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    item_collected_port = new("item_collected_port", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    // TODO: fetch the virtual interface handle set by the testbench top,
    uvm_config_db#(virtual uvm_skeleton_if.monitor)::get(this, "", "vif", vif);
  endfunction

  task run_phase(uvm_phase phase);
    forever begin
      collect_item();
    end
  endtask

  // TODO: implement the actual sampling of one transaction from the bus.
  task collect_item();
    uvm_skeleton_item pending_item;
    uvm_skeleton_item completed_item;
    forever begin
      @(vif.monitor_cb);
      if (pending_item != null) begin
        completed_item = uvm_skeleton_item::type_id::create("completed_item");
        completed_item.copy(pending_item);
        completed_item.read_data       = vif.monitor_cb.hrdata;
        completed_item.response_error  = vif.monitor_cb.hresp;
        completed_item.slave0_selected = vif.monitor_cb.slave0_sel;
        completed_item.slave1_selected = vif.monitor_cb.slave1_sel;
        item_collected_port.write(completed_item);
        pending_item = null;
      end
      if (vif.monitor_cb.hready && vif.monitor_cb.htrans[1]) begin
        pending_item = uvm_skeleton_item::type_id::create("pending_item");
        pending_item.address    = vif.monitor_cb.haddr;
        pending_item.trans      = vif.monitor_cb.htrans;
        pending_item.write      = vif.monitor_cb.hwrite;
        pending_item.size       = vif.monitor_cb.hsize;
        pending_item.write_data = vif.monitor_cb.hwdata;
      end
    end
  endtask

endclass
