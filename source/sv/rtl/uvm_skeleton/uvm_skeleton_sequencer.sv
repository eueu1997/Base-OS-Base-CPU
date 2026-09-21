// -----------------------------------------------------------------------------
// Class       : uvm_skeleton_sequencer
// File        : uvm_skeleton_sequencer.sv
// Author      : spt9pad
// Date        : 2026-09-16
// Version     : v1.0
//
// Functionality
// - Arbitrates sequence items produced by sequences and forwards them to the
//   driver via the standard TLM seq_item_export/seq_item_port handshake.
// - Usually no code is needed here beyond the parameterized base class;
//   override only if you need custom arbitration or a layering scheme
//   (e.g. a virtual sequencer coordinating multiple agents).
// -----------------------------------------------------------------------------
class uvm_skeleton_sequencer extends uvm_sequencer #(uvm_skeleton_item);
  `uvm_component_utils(uvm_skeleton_sequencer)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

endclass
