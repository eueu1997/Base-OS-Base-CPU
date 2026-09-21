class ahb_lite_base_test extends uvm_test;
  `uvm_component_utils(ahb_lite_base_test)

  ahb_lite_env env;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = ahb_lite_env::type_id::create("env", this);
  endfunction

  task run_phase(uvm_phase phase);
    ahb_lite_sequence sequence;
    phase.raise_objection(this);
    sequence = ahb_lite_sequence::type_id::create("sequence");
    sequence.start(env.agent.sequencer);
    repeat (2) @(env.agent.monitor.vif.monitor_cb);
    phase.drop_objection(this);
  endtask
endclass