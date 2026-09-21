########################################################################
# SDC Constraints : riscv_top — function mode
# Block    : riscv_top
# Technology : spt9u, 10-track (Infineon)
# Synthesis  : Cadence Genus, framework Camino
#
# Ports: clk_i, rst_ni (async active-low reset), illegal_instr_o
########################################################################

## ---- Clock definition ------------------------------------------------
set clk_period 10.000 ;# 100 MHz core clock

create_clock -name clk_core \
             -period $clk_period \
             -waveform [list 0 [expr {$clk_period / 2.0}]] \
             [get_ports clk_i]

## ---- Clock uncertainty -----------------------------------------------
set_clock_uncertainty -setup 0.150 [get_clocks clk_core]
set_clock_uncertainty -hold  0.050 [get_clocks clk_core]

## ---- Asynchronous reset : false path ---------------------------------
set_false_path -from [get_ports rst_ni]

## ---- I/O delays (40% of clock period) --------------------------------
set in_delay  [expr {$clk_period * 0.40}]
set out_delay [expr {$clk_period * 0.40}]

set_input_delay  $in_delay  -clock clk_core \
    [remove_from_collection [all_inputs] [get_ports {clk_i rst_ni}]]

set_output_delay $out_delay -clock clk_core \
    [all_outputs]

## ---- Drive / load (default, override if actual drivers are known) ----
set_driving_cell -lib_cell H150_SBUF4 -pin Z [all_inputs]
set_load         0.00689 [all_outputs]

########################################################################
# End of riscv_top.function.tcl
########################################################################
