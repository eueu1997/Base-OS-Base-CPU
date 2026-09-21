// -----------------------------------------------------------------------------
// Class       : uvm_skeleton_agent
// File        : uvm_skeleton_agent.sv
// Author      : spt9pad
// Date        : 2026-09-16
// Version     : v1.0
//
// Functionality
// - Groups sequencer + driver + monitor for one interface/protocol.
// - Active (UVM_ACTIVE) agents drive stimulus; passive (UVM_PASSIVE) agents
//   only monitor (useful e.g. to observe a bus without owning it).
// - TODO: add a coverage collector here if you want it per-agent instead of
//   at the env level.
// -----------------------------------------------------------------------------
class uvm_skeleton_agent extends uvm_agent;
  `uvm_component_utils(uvm_skeleton_agent)

  uvm_skeleton_sequencer sequencer;
  uvm_skeleton_driver    driver;
  uvm_skeleton_monitor   monitor;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    monitor = uvm_skeleton_monitor::type_id::create("monitor", this);
    if (is_active == UVM_ACTIVE) begin
      sequencer = uvm_skeleton_sequencer::type_id::create("sequencer", this);
      driver    = uvm_skeleton_driver::type_id::create("driver", this);
    end
  endfunction

  function void connect_phase(uvm_phase phase);
    if (is_active == UVM_ACTIVE) begin
      driver.seq_item_port.connect(sequencer.seq_item_export);
    end
  endfunction

endclass
