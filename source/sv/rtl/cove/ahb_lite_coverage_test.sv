class ahb_lite_coverage_test extends ahb_lite_base_test;
  `uvm_component_utils(ahb_lite_coverage_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    ahb_lite_coverage_sequence sequence;
    phase.raise_objection(this);
    sequence = ahb_lite_coverage_sequence::type_id::create("coverage_sequence");
    sequence.start(env.agent.sequencer);
    repeat (3) @(env.agent.monitor.vif.monitor_cb);
    phase.drop_objection(this);
  endtask
endclass