########################################################################
# SDC Constraints : riscv_top — function1 mode
# (Secondary functional mode — same clock, alternate timing margins)
########################################################################

set clk_period 10.000 ;# 100 MHz

create_clock -name clk_core \
             -period $clk_period \
             -waveform [list 0 [expr {$clk_period / 2.0}]] \
             [get_ports clk_i]

set_clock_uncertainty -setup 0.150 [get_clocks clk_core]
set_clock_uncertainty -hold  0.050 [get_clocks clk_core]

set_false_path -from [get_ports rst_ni]

set in_delay  [expr {$clk_period * 0.40}]
set out_delay [expr {$clk_period * 0.40}]

set_input_delay  $in_delay  -clock clk_core \
    [remove_from_collection [all_inputs] [get_ports {clk_i rst_ni}]]
set_output_delay $out_delay -clock clk_core \
    [all_outputs]

set_driving_cell -lib_cell H150_SBUF4 -pin Z [all_inputs]
set_load         0.00689 [all_outputs]

########################################################################
# End of riscv_top.function1.tcl
########################################################################
