// -----------------------------------------------------------------------------
// Class       : uvm_skeleton_sequence
// File        : uvm_skeleton_sequence.sv
// Author      : spt9pad
// Date        : 2026-09-16
// Version     : v1.0
//
// Functionality
// - Empty sequence template: start from this skeleton to write new stimulus
//   sequences without repeating the boilerplate.
// - Use start_item()/finish_item() (or `uvm_do` macros) around every item you
//   want to send to the driver through the sequencer.
// -----------------------------------------------------------------------------
class uvm_skeleton_sequence extends uvm_sequence #(uvm_skeleton_item);
  `uvm_object_utils(uvm_skeleton_sequence)

  function new(string name = "uvm_skeleton_sequence");
    super.new(name);
  endfunction


  task body();
    drive_dut(32'h0, 2'b00, 1'b0, 3'b000, 32'h0);
    drive_dut(32'h0, 2'b01, 1'b1, 3'b100, 32'hdeadbeef);
  endtask

  task drive_dut(bit [31:0] addr, bit [1:0] trans, bit write, bit [2:0] size, bit [31:0] write_data);
    uvm_skeleton_item item ;
    item = uvm_skeleton_item::type_id::create("uvm_skeleton_item");
    start_item(item);
    item.haddr    = addr;
    item.trans    = trans;
    item.write    = write;
    item.size     = size;
    item.write_data = write_data;
    finish_item(item);
  endtask
endclass
