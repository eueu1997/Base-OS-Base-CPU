class ahb_lite_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(ahb_lite_scoreboard)

  uvm_analysis_imp #(ahb_lite_item, ahb_lite_scoreboard) analysis_export;
  bit [31:0] expected_memory [longint unsigned];

  function new(string name, uvm_component parent);
    super.new(name, parent);
    analysis_export = new("analysis_export", this);
  endfunction

  function void write(ahb_lite_item item);
    longint unsigned key = item.address;
    if (item.response_error) begin
      if ((item.address == 32'h0002_0000) ||
          (item.address[1:0] != 2'b00)) begin
        `uvm_info("AHB_SCB", $sformatf("Expected error at 0x%08h", item.address), UVM_LOW)
      end else begin
        `uvm_error("AHB_SCB", $sformatf("Unexpected error at 0x%08h", item.address))
      end
    end else if (item.write) begin
      expected_memory[key] = item.write_data;
    end else if (expected_memory.exists(key)) begin
      if (item.read_data !== expected_memory[key]) begin
        `uvm_error("AHB_SCB", $sformatf("Read mismatch at 0x%08h: expected 0x%08h, got 0x%08h",
                                         item.address, expected_memory[key], item.read_data))
      end
    end else if (item.read_data !== 32'b0) begin
      `uvm_error("AHB_SCB", $sformatf("Uninitialized read at 0x%08h returned 0x%08h",
                                       item.address, item.read_data))
    end
  endfunction
endclass