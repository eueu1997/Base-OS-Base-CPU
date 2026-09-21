#-----------------------------------------------------------------------------#
# Template to setup clock constraints
#-----------------------------------------------------------------------------#

# Remove following two lines once this file has been adapted for the design
puts "ERROR: Please edit '[info script]'. (IFX)"
exit 1

# Variables required for clock definition in this script:
#
# CLK_OVERCON:      Overconstraining factor (phase specific):
#                     * Prelayout stage (incl. initial synthesis, prelayout
#                       STA, until clock tree synthesis): 10% overconstraining
#                     * Postlayout stage (after clock tree synthesis): no overconstraining
#                     * Signoff STA: No overconstraining
# PERIOD :      Clock period for xx Mhz clock (w/o overconstraining)
# TRANSITION:   Clock transition
# LATENCY_xxx:  Clock latency
# JITTER:       Clock uncertainty due to jitter (in ns)
#               Used only for 'setup' checks, for both pre- and post-layout
# SKEW:         Clock uncertainty due to clock skew
#----------------------------------------------------------------------------#
puts "INFO: Defining Clocks. (IFX)"
##
# Overconstraining in PreLayout by Tightening the clock period 
#
if { $phase == "prelayout" } {
  set CLK_OVERCON    1.10
} else {
  set CLK_OVERCON    1.00
}
puts "WARNING: Phase set to $phase - setting overconstraining factor to ${CLK_OVERCON}. (IFX)"
puts "WARNING: Overconstraining applied through clock uncertainty: clock_period - clock_period / overcon_factor. (IFX)"

#-----------------------------------------------------------------------------#
# Define the clock name and port/pin which is clock root
#-----------------------------------------------------------------------------#
# 1. define all clock names - these are generic names not necessarily the port/pin names
set design_clock_names [list <all clock names in design>]
# 2. For each clock define the target conditions
set design_clocks(CLOCKNAME,PERIOD)      <period_in_ns> ;# clock period in ns
set design_clocks(CLOCKNAME,SOURCE)      <clock_source> ;# leaf empty for no source
set design_clocks(CLOCKNAME,LATENCY_MAX) <clock_tree_delay_in_ns>;
set design_clocks(CLOCKNAME,LATENCY_MIN) <clock_tree_delay_in_ns>;
set design_clocks(CLOCKNAME,TRANSITION_MAX)  <clock_transition_for_setup_in_ns>;
set design_clocks(CLOCKNAME,TRANSITION_MIN)  <clock_transition_for_hold_in_ns>;
set design_clocks(CLOCKNAME,SKEW_MAX)        <clock_skew_for_setup_in_ns>;
set design_clocks(CLOCKNAME,SKEW_MIN)        <clock_skew_for_hold_in_ns>;
set design_clocks(CLOCKNAME,JITTER_MAX)      <clock_jitter_for_setup_in_ns>;
set design_clocks(CLOCKNAME,JITTER_MIN)      <clock_jitter_for_hold_in_ns>;

# example with 3 clocks
set design_clock_names [list core_clk input_clk_v output_clk_v]
set design_clocks(core_clk,PERIOD)              3.5 ;# clock period in ns
set design_clocks(input_clk_v,PERIOD)           5.0 ;# clock period in ns
set design_clocks(output_clk_v,PERIOD)          5.0 ;# clock period in ns
set design_clocks(core_clk,SOURCE)              [get_pins clku_inst/clkroot_inst/coreclk_o] ;# could be multiple
set design_clocks(input_clk_v,SOURCE)           "" ;# leaf empty for no source
set design_clocks(output_clk_v,SOURCE)          "" ;# leaf empty for no source
set design_clocks(core_clk,LATENCY_MAX)         3.0
set design_clocks(input_clk_v,LATENCY_MAX)      3.0
set design_clocks(output_clk_v,LATENCY_MAX)     3.0
set design_clocks(core_clk,LATENCY_MIN)         1.0
set design_clocks(input_clk_v,LATENCY_MIN)      1.0
set design_clocks(output_clk_v,LATENCY_MIN)     1.0
set design_clocks(core_clk,TRANSITION_MAX)      0.2
set design_clocks(input_clk_v,TRANSITION_MAX)   0.2
set design_clocks(output_clk_v,TRANSITION_MAX)  0.2
set design_clocks(core_clk,TRANSITION_MIN)      0.1
set design_clocks(input_clk_v,TRANSITION_MIN)   0.1
set design_clocks(output_clk_v,TRANSITION_MIN)  0.1
set design_clocks(core_clk,SKEW_MAX)            0.3
set design_clocks(input_clk_v,SKEW_MAX)         0.5
set design_clocks(output_clk_v,SKEW_MAX)        0.5
set design_clocks(core_clk,SKEW_MIN)            0.1
set design_clocks(input_clk_v,SKEW_MIN)         0.15
set design_clocks(output_clk_v,SKEW_MIN)        0.15
set design_clocks(core_clk,JITTER_MAX)          0.05
set design_clocks(input_clk_v,JITTER_MAX)       0.1
set design_clocks(output_clk_v,JITTER_MAX)      0.1
set design_clocks(core_clk,JITTER_MIN)          0.05
set design_clocks(input_clk_v,JITTER_MIN)       0
set design_clocks(output_clk_v,JITTER_MIN)      0

#
# End of Definition Part
#

#-----------------------------------------------------------------------------#
# Automated script part - do not edit behind this line (except necessary)
#-----------------------------------------------------------------------------#
foreach single_clock $design_clock_names {
    set clock_period $design_clocks(${single_clock},PERIOD)
    set clock_source $design_clocks(${single_clock},SOURCE)
    # add the clock over constraining
    set clock_period [expr $clock_period / $CLK_OVERCON]
    eval "create_clock -period $clock_period -name $single_clock $clock_source"
    
    # define the clock attributes
   if { $phase == "prelayout" } {
       set_clock_latency -max $design_clocks(${single_clock},LATENCY_MAX) $single_clock
       set_clock_latency -min $design_clocks(${single_clock},LATENCY_MIN) $single_clock
       if { $clock_source != ""} {
           set_clock_transition -max $design_clocks(${single_clock},TRANSITION_MAX) $single_clock
           set_clock_transition -min $design_clocks(${single_clock},TRANSITION_MIN) $single_clock
       }
       set_clock_uncertainty -setup  [expr $design_clocks(${single_clock},SKEW_MAX) + $design_clocks(${single_clock},JITTER_MAX)] $single_clock
       set_clock_uncertainty -hold   [expr $design_clocks(${single_clock},SKEW_MIN) + $design_clocks(${single_clock},JITTER_MIN)] $single_clock
   } else {
      set_clock_uncertainty -setup  $design_clocks(${single_clock},JITTER_MAX) $single_clock
      set_clock_uncertainty -hold   $design_clocks(${single_clock},JITTER_MIN) $single_clock
   }
    
}

# EoF DESIGN.clocks.tcl

