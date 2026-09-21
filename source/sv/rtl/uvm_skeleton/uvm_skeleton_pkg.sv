// -----------------------------------------------------------------------------
// Package     : uvm_skeleton_pkg
// File        : uvm_skeleton_pkg.sv
// Author      : spt9pad
// Date        : 2026-09-16
// Version     : v1.0
//
// Functionality
// - Collects the minimum UVM class hierarchy: item, sequencer, driver,
//   monitor, agent, sequence, env, test.
// - Include order matters: base classes (item) before the classes that use
//   them (sequencer, driver, monitor), and env/test last.
// - This is intentionally minimal: no scoreboard/coverage are included, see
//   the TODOs in uvm_skeleton_env.sv for where to plug them in.
// -----------------------------------------------------------------------------
package uvm_skeleton_pkg;

  import uvm_pkg::*;
  `include "uvm_macros.svh"

  `include "uvm_skeleton_item.sv"
  `include "uvm_skeleton_sequencer.sv"
  `include "uvm_skeleton_driver.sv"
  `include "uvm_skeleton_monitor.sv"
  `include "uvm_skeleton_agent.sv"
  `include "uvm_skeleton_sequence.sv"
  `include "uvm_skeleton_env.sv"
  `include "uvm_skeleton_test.sv"

endpackage
