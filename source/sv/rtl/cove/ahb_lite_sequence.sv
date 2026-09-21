class ahb_lite_sequence extends uvm_sequence #(ahb_lite_item);
  `uvm_object_utils(ahb_lite_sequence)

  function new(string name = "ahb_lite_sequence");
    super.new(name);
  endfunction

  task body();
    write_access(32'h0000_0010, 32'h1111_aaaa);
    read_access (32'h0000_0010);
    write_access(32'h0001_0020, 32'h2222_bbbb);
    read_access (32'h0001_0020);
    read_access (32'h0000_0024);
    read_access (32'h0002_0000);
  endtask

  task write_access(bit [31:0] address, bit [31:0] data);
    ahb_lite_item item = ahb_lite_item::type_id::create("write_item");
    start_item(item);
    item.address    = address;
    item.trans      = HTRANS_NONSEQ;
    item.write      = 1'b1;
    item.size       = 3'b010;
    item.write_data = data;
    finish_item(item);
  endtask

  task read_access(bit [31:0] address);
    ahb_lite_item item = ahb_lite_item::type_id::create("read_item");
    start_item(item);
    item.address    = address;
    item.trans      = HTRANS_NONSEQ;
    item.write      = 1'b0;
    item.size       = 3'b010;
    item.write_data = '0;
    finish_item(item);
  endtask
endclass