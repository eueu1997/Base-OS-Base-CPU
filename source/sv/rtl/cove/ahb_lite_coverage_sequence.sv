class ahb_lite_coverage_sequence extends uvm_sequence #(ahb_lite_item);
  `uvm_object_utils(ahb_lite_coverage_sequence)

  function new(string name = "ahb_lite_coverage_sequence");
    super.new(name);
  endfunction

  task body();
    send_access(32'h0000_0000, 1'b1, 3'b000, 32'h0000_00aa);
    send_access(32'h0000_0004, 1'b0, 3'b000, 32'h0000_0000);
    send_access(32'h0000_0008, 1'b1, 3'b001, 32'h0000_bbbb);
    send_access(32'h0000_000c, 1'b0, 3'b001, 32'h0000_0000);
    send_access(32'h0000_0010, 1'b1, 3'b010, 32'hcccc_cccc);
    send_access(32'h0000_0010, 1'b0, 3'b010, 32'h0000_0000);
    send_access(32'h0001_0000, 1'b1, 3'b010, 32'hdddd_dddd);
    send_access(32'h0001_0000, 1'b0, 3'b010, 32'h0000_0000);
    send_access(32'h0000_0001, 1'b0, 3'b010, 32'h0000_0000);
    send_access(32'h0001_0002, 1'b1, 3'b010, 32'heeee_eeee);
    send_access(32'h0002_0000, 1'b0, 3'b010, 32'h0000_0000);
    send_access(32'h0003_0000, 1'b1, 3'b010, 32'hffff_ffff);
    send_access(32'h0000_0014, 1'b0, 2'b11, 32'h0000_0000, HTRANS_NONSEQ);
    send_access(32'h0000_0018, 1'b0, 3'b010, 32'h0000_0000, HTRANS_SEQ);
  endtask

  task send_access(bit [31:0] address,
                   bit        write,
                   bit [2:0]  size,
                   bit [31:0] write_data,
                   bit [1:0]  trans = HTRANS_NONSEQ);
    ahb_lite_item item = ahb_lite_item::type_id::create("coverage_item");
    start_item(item);
    item.address    = address;
    item.trans      = trans;
    item.write      = write;
    item.size       = size;
    item.write_data = write_data;
    finish_item(item);
  endtask
endclass