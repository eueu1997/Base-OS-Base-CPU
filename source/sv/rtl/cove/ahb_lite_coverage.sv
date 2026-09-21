class ahb_lite_coverage extends uvm_subscriber #(ahb_lite_item);
  `uvm_component_utils(ahb_lite_coverage)

  bit [31:0] address_q;
  bit [1:0]  trans_q;
  bit        write_q;
  bit [2:0]  size_q;
  bit        response_error_q;
  bit        slave0_selected_q;
  bit        slave1_selected_q;
  bit [2:0]  region_q;
  bit        aligned_q;
  bit [1:0]  slave_select_q;

  covergroup ahb_lite_cg;
    option.per_instance = 1;

    cp_region: coverpoint region_q {
      bins slave0       = {3'd0};
      bins slave1       = {3'd1};
      bins unmapped     = {3'd2};
      bins other_region = {3'd3};
    }

    cp_transfer: coverpoint trans_q {
      bins nonseq = {2'b10};
      bins seq    = {2'b11};
      ignore_bins idle = {2'b00};
      ignore_bins busy = {2'b01};
    }

    cp_access: coverpoint write_q {
      bins read  = {1'b0};
      bins write = {1'b1};
    }

    cp_size: coverpoint size_q {
      bins byte_transfer = {3'b000};
      bins half_transfer = {3'b001};
      bins word_transfer = {3'b010};
      bins other_size    = default;
    }

    cp_alignment: coverpoint aligned_q {
      bins aligned     = {1'b1};
      bins misaligned  = {1'b0};
    }

    cp_response: coverpoint response_error_q {
      bins okay  = {1'b0};
      bins error = {1'b1};
    }

    cp_slave_select: coverpoint slave_select_q {
      bins no_slave = {2'b00};
      bins slave0   = {2'b01};
      bins slave1   = {2'b10};
      illegal_bins both_slaves = {2'b11};
    }

    region_x_access: cross cp_region, cp_access;
    region_x_response: cross cp_region, cp_response;
    size_x_access: cross cp_size, cp_access;
    alignment_x_response: cross cp_alignment, cp_response;
    transfer_x_region: cross cp_transfer, cp_region;
  endgroup

  function new(string name, uvm_component parent);
    super.new(name, parent);
    ahb_lite_cg = new();
  endfunction

  function void write(ahb_lite_item item);
    address_q           = item.address;
    trans_q             = item.trans;
    write_q             = item.write;
    size_q              = item.size;
    response_error_q    = item.response_error;
    slave0_selected_q   = item.slave0_selected;
    slave1_selected_q   = item.slave1_selected;
    aligned_q           = (item.address[1:0] == 2'b00);
    slave_select_q      = {item.slave1_selected, item.slave0_selected};

    if ((item.address & 32'hFFFF_F000) == 32'h0000_0000) begin
      region_q = 3'd0;
    end else if ((item.address & 32'hFFFF_F000) == 32'h0001_0000) begin
      region_q = 3'd1;
    end else if ((item.address & 32'hFFFF_F000) == 32'h0002_0000) begin
      region_q = 3'd2;
    end else begin
      region_q = 3'd3;
    end

    ahb_lite_cg.sample();
  endfunction

  function void report_phase(uvm_phase phase);
    `uvm_info("AHB_COV", $sformatf("AHB-Lite functional coverage: %0.2f%%",
                                   ahb_lite_cg.get_inst_coverage()), UVM_NONE)
  endfunction
endclass