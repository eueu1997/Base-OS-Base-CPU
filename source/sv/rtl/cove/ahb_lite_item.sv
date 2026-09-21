class ahb_lite_item extends uvm_sequence_item;
  rand bit [31:0] address;
  rand bit [1:0]  trans;
  rand bit        write;
  rand bit [2:0]  size;
  rand bit [31:0] write_data;
       bit [31:0] read_data;
       bit        response_error;
       bit        slave0_selected;
       bit        slave1_selected;

  `uvm_object_utils_begin(ahb_lite_item)
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

  function new(string name = "ahb_lite_item");
    super.new(name);
  endfunction
endclass