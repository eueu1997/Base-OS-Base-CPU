class ahb_lite_sequencer extends uvm_sequencer #(ahb_lite_item);
  `uvm_component_utils(ahb_lite_sequencer)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
endclass