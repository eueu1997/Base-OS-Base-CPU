// -----------------------------------------------------------------------------
// Class       : uvm_skeleton_item
// File        : uvm_skeleton_item.sv
// Author      : spt9pad
// Date        : 2026-09-16
// Version     : v1.0
//
// Functionality
// - Sequence item (transaction) exchanged between sequences, driver and
//   monitor. Add here the fields that describe one transaction on the bus.
// - Add `rand` constraints to control stimulus generation from sequences.
// - Override do_copy/do_compare/convert2string if you need custom field
//   handling beyond what the `uvm_field_*` macros (or `uvm_object_utils`
//   automation) provide.
// -----------------------------------------------------------------------------
class uvm_skeleton_item extends uvm_sequence_item;
  rand bit [31:0] address;
  rand bit [1:0]  trans;
  rand bit        write;
  rand bit [2:0]  size;
  rand bit [31:0] write_data;
       bit [31:0] read_data;
       bit        response_error;
       bit        slave0_selected;
       bit        slave1_selected;

  `uvm_object_utils_begin(uvm_skeleton_item)
    `uvm_field_int(address, UVM_ALL_ON)
    `uvm_field_int(trans, UVM_ALL_ON)
    `uvm_field_int(write, UVM_ALL_ON)
    `uvm_field_int(size, UVM_ALL_ON)
    `uvm_field_int(write_data, UVM_ALL_ON)
    `uvm_field_int(read_data, UVM_ALL_ON)
    `uvm_field_int(response_error, UVM_ALL_ON)
    `uvm_field_int(slave0_selected, UVM_ALL_ON)
    `uvm_field_int(slave1_selected, UVM_ALL_ON)
  `uvm_object_utils_end
endclass
