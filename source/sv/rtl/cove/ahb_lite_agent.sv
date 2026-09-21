class ahb_lite_agent extends uvm_agent;
  `uvm_component_utils(ahb_lite_agent)

  ahb_lite_sequencer sequencer;
  ahb_lite_driver    driver;
  ahb_lite_monitor   monitor;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    monitor = ahb_lite_monitor::type_id::create("monitor", this);
    if (is_active == UVM_ACTIVE) begin
      sequencer = ahb_lite_sequencer::type_id::create("sequencer", this);
      driver    = ahb_lite_driver::type_id::create("driver", this);
    end
  endfunction

  function void connect_phase(uvm_phase phase);
    if (is_active == UVM_ACTIVE) begin
      driver.seq_item_port.connect(sequencer.seq_item_export);
    end
  endfunction
endclass