########################################################################
# SDC Constraints : riscv_top — scan_shift mode
# In scan shift mode the clock runs slow (10 MHz) and timing is relaxed.
########################################################################

set clk_period 100.000 ;# 10 MHz scan shift clock

create_clock -name clk_scan_shift \
             -period $clk_period \
             -waveform [list 0 [expr {$clk_period / 2.0}]] \
             [get_ports clk_i]

set_clock_uncertainty 0.100 [get_clocks clk_scan_shift]

set_false_path -from [get_ports rst_ni]

# Relax I/O during shift (80% of clock period)
set_input_delay  [expr {$clk_period * 0.80}] -clock clk_scan_shift \
    [remove_from_collection [all_inputs] [get_ports {clk_i rst_ni}]]
set_output_delay [expr {$clk_period * 0.80}] -clock clk_scan_shift \
    [all_outputs]

########################################################################
# End of riscv_top.scan_shift.tcl
########################################################################
