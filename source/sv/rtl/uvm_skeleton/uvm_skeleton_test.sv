// -----------------------------------------------------------------------------
// Class       : uvm_skeleton_test
// File        : uvm_skeleton_test.sv
// Author      : spt9pad
// Date        : 2026-09-16
// Version     : v1.0
//
// Functionality
// - Base test: builds the environment and starts the default sequence on the
//   agent sequencer during the run_phase.
// - TODO: derive new test classes from this one for each scenario, only
//   overriding run_phase to start a different sequence.
// -----------------------------------------------------------------------------
class uvm_skeleton_test extends uvm_test;
  `uvm_component_utils(uvm_skeleton_test)

  uvm_skeleton_env env;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = uvm_skeleton_env::type_id::create("env", this);
  endfunction

  task run_phase(uvm_phase phase);
    uvm_skeleton_sequence seq = uvm_skeleton_sequence::type_id::create("seq");
    phase.raise_objection(this);
    seq.start(env.agent.sequencer);
    phase.drop_objection(this);
  endtask

endclass
