// -----------------------------------------------------------------------------
// Class       : uvm_skeleton_env
// File        : uvm_skeleton_env.sv
// Author      : spt9pad
// Date        : 2026-09-16
// Version     : v1.0
//
// Functionality
// - Top-level reusable verification environment: instantiates the agent(s)
//   and wires them to a scoreboard/coverage collector.
// - TODO: add a `uvm_skeleton_scoreboard` (extends uvm_scoreboard, with an
//   analysis_export) if you need reference-model checking.
// - TODO: add a `uvm_skeleton_coverage` (extends uvm_subscriber or uvm_component
//   with an analysis_export + covergroup) for functional coverage.
// - TODO: add more agents here if the DUT has multiple interfaces.
// -----------------------------------------------------------------------------
class uvm_skeleton_env extends uvm_env;
  `uvm_component_utils(uvm_skeleton_env)

  uvm_skeleton_agent agent;
  uvm_skeleton_scoreboard scoreboard;
  uvm_skeleton_coverage coverage;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    agent = uvm_skeleton_agent::type_id::create("agent", this);
    scoreboard = uvm_skeleton_scoreboard::type_id::create("scoreboard", this);
    coverage   = uvm_skeleton_coverage::type_id::create("coverage", this);
  endfunction

  function void connect_phase(uvm_phase phase);
    agent.monitor.item_collected_port.connect(scoreboard.analysis_export);
    agent.monitor.item_collected_port.connect(coverage.analysis_export);
  endfunction

endclass
