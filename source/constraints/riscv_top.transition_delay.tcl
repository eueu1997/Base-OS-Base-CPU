########################################################################
# SDC Constraints : riscv_top — transition_delay mode
# Used for at-speed test with slow-fast or fast-slow transitions.
########################################################################

set clk_period 10.000 ;# 100 MHz at-speed clock

create_clock -name clk_transition \
             -period $clk_period \
             -waveform [list 0 [expr {$clk_period / 2.0}]] \
             [get_ports clk_i]

set_clock_uncertainty -setup 0.150 [get_clocks clk_transition]
set_clock_uncertainty -hold  0.050 [get_clocks clk_transition]

set_false_path -from [get_ports rst_ni]

set in_delay  [expr {$clk_period * 0.40}]
set out_delay [expr {$clk_period * 0.40}]

set_input_delay  $in_delay  -clock clk_transition \
    [remove_from_collection [all_inputs] [get_ports {clk_i rst_ni}]]
set_output_delay $out_delay -clock clk_transition \
    [all_outputs]

########################################################################
# End of riscv_top.transition_delay.tcl
########################################################################
