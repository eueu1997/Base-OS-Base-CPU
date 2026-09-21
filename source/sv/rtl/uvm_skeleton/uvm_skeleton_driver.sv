// -----------------------------------------------------------------------------
// Class       : uvm_skeleton_driver
// File        : uvm_skeleton_driver.sv
// Author      : spt9pad
// Date        : 2026-09-16
// Version     : v1.0
//
// Functionality
// - Pulls one item at a time from the sequencer (get_next_item) and drives
//   it onto the DUT pins through the virtual interface.
// - Signals item completion back to the sequencer with item_done().
// - TODO: add reset handling (wait for rst_n deassertion before driving).
// - TODO: add protocol-specific timing (wait states, back-pressure on
//   req_ready, etc.).
// -----------------------------------------------------------------------------
class uvm_skeleton_driver extends uvm_driver #(uvm_skeleton_item);
  `uvm_component_utils(uvm_skeleton_driver)

  virtual uvm_skeleton_if vif;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    uvm_config_db#(virtual uvm_skeleton_if.master)::get(this, "", "vif", vif);
  endfunction

  task run_phase(uvm_phase phase);
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
      seq_item_port.item_done();
    end
  endtask

  // TODO: implement the actual pin wiggling for one transaction.
  task drive_item(uvm_skeleton_item item);
    `uvm_info(get_type_name(), $sformatf("driving %s", item.convert2string()), UVM_MEDIUM)
    // @(posedge vif.clk);
    // vif.req_valid <= 1'b1;
    // vif.req_data  <= item.data;
    // wait (vif.req_ready);
    // @(posedge vif.clk);
    // vif.req_valid <= 1'b0;
  endtask

endclass
