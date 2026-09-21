package ahb_lite_uvm_pkg;

  import uvm_pkg::*;
  `include "uvm_macros.svh"

  typedef enum bit [1:0] {
    HTRANS_IDLE   = 2'b00,
    HTRANS_BUSY   = 2'b01,
    HTRANS_NONSEQ = 2'b10,
    HTRANS_SEQ    = 2'b11
  } ahb_htrans_e;

  `include "ahb_lite_item.sv"
  `include "ahb_lite_sequence.sv"
  `include "ahb_lite_sequencer.sv"
  `include "ahb_lite_driver.sv"
  `include "ahb_lite_monitor.sv"
  `include "ahb_lite_agent.sv"
  `include "ahb_lite_scoreboard.sv"
  `include "ahb_lite_coverage.sv"
  `include "ahb_lite_env.sv"
  `include "ahb_lite_test.sv"
  `include "ahb_lite_coverage_sequence.sv"
  `include "ahb_lite_coverage_test.sv"

endpackage