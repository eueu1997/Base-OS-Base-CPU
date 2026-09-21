########################################################################
# SDC Constraints : riscv_top — scan_capture mode
# Capture uses functional clock but may have a longer cycle.
########################################################################

set clk_period 10.000 ;# 100 MHz functional clock for capture

create_clock -name clk_scan_capture \
             -period $clk_period \
             -waveform [list 0 [expr {$clk_period / 2.0}]] \
             [get_ports clk_i]

set_clock_uncertainty -setup 0.200 [get_clocks clk_scan_capture]
set_clock_uncertainty -hold  0.100 [get_clocks clk_scan_capture]

set_false_path -from [get_ports rst_ni]

set in_delay  [expr {$clk_period * 0.40}]
set out_delay [expr {$clk_period * 0.40}]

set_input_delay  $in_delay  -clock clk_scan_capture \
    [remove_from_collection [all_inputs] [get_ports {clk_i rst_ni}]]
set_output_delay $out_delay -clock clk_scan_capture \
    [all_outputs]

########################################################################
# End of riscv_top.scan_capture.tcl
########################################################################
