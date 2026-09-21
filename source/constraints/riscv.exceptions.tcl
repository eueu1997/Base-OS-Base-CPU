#-----------------------------------------------------------------------------#
# Template to setup timing exception constraints
#-----------------------------------------------------------------------------#

# Remove following two lines once this file has been adapted for the design
puts "ERROR: Please edit '[info script]'. (IFX)"
exit 1

# Timing exceptions
puts "INFO: Define timing exceptions. (IFX)"

# Multi cycle paths
# Multicycle path from fast clock domain to external slow clock
set_multicycle_path 2 -setup -start -from [get_clocks "CORE_CLK"] \
                                    -to   [get_clocks slow_clk_ext]
set_multicycle_path 1 -hold  -start -from [get_clocks "CORE_CLK"] \
                                    -to   [get_clocks slow_clk_ext]
# multicycle from external to external
set_multicycle_path 2 -setup -from [get_clock slow_clk_ext] \
                             -to   [get_clock slow_clk_ext]
set_multicycle_path 1 -hold  -from [get_clock slow_clk_ext] \
                             -to   [get_clock slow_clk_ext]
# Asynchronous power on reset
set_multicycle_path 2 -setup -start -through [get_ports porst_n]
set_multicycle_path 1 -hold  -start -through [get_ports porst_n]

if { $_pt || $_icc } {
  set_multicycle_path 2 -setup \
       -to [get_pins lebu_ct_inst/lebu_bfc_inst/fsm/lebu_bfc_baa_int_reg/RN]
  set_multicycle_path 1 -hold  \
       -to [get_pins lebu_ct_inst/lebu_bfc_inst/fsm/lebu_bfc_baa_int_reg/RN]
  set_multicycle_path 2 -setup \
       -to [get_pins lebu_ct_inst/lebu_bfc_inst/fsm/lebu_bfc_adv_int_reg/RN]
  set_multicycle_path 1 -hold  \
       -to [get_pins lebu_ct_inst/lebu_bfc_inst/fsm/lebu_bfc_adv_int_reg/RN]
}

# False paths
if { $_dc } {

} else {
  set_false_path -from [get_pins inst_pwr_dt/fden_latched_reg*/EN]
  set_false_path -from [get_pins inst_pwr_sy/brk_in_n_reg/EN]
  set_false_path -from [get_pins inst_pwr_sy/bypass_reg/EN]
  set_false_path -from [get_pins inst_pwr_sy/cfg_reg*/EN]
  set_false_path -from [get_pins inst_pwr_sy/int_nmi_n_reg/EN]
  set_false_path -from [get_pins inst_pwr_sy/int_tms_reg/EN]
  set_false_path -from [get_pins inst_pwr_sy/pwr_swopt_reg*/EN]
  set_false_path -from [get_pins inst_pwr_sy/sy_te_cfg_reg*/EN]
  set_false_path -from [get_pins inst_pwr_sy/sy_txd1a_reg/EN]
  set_false_path -from [get_pins inst_pwr_sy/testmode_reg/EN]
}

# EoF DESIGN.exceptions.tcl
