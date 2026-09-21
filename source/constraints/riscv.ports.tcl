#-----------------------------------------------------------------------------#
# Template to setup port timing constraints
#-----------------------------------------------------------------------------#

# Remove following two lines once this file has been adapted for the design
puts "ERROR: Please edit '[info script]'. (IFX)"
exit 1

# Define port lists for actions relative to the clocks
set in_ports  [get_ports {"reset" "address_i" "cmd_ready" "cmd_i" "data" "tsi2"}]
set out_ports [get_ports {"error_o" "carry_o" "cmd_done" "mux_o" "data" "error_pll"}]

# Define input delays according to the virtual clock(s)
#set_input_delay <delay> -clock <virtual_clock_name> -rise/-fall \
#                        -max/-min -add_delay <port_list>
set_input_delay [expr 0.40 * $design_clocks(input_clk_v,PERIOD)] -clock input_clk_v -add_delay $in_ports

# Define output delays according to the virtual clock(s)
#set_output_delay <delay> -clock <virtual_clock_name> -rise/-fall \
#                         -max/-min -add_delay <port_list>
set_output_delay [expr 0.70 * $design_clocks(output_clk_v,PERIOD)] -clock output_clk_v -add_delay $out_ports

# Boundary conditions
# Driver definition for data input ports on module level
# Note: This constraint is applied to all input ports first
#       For clock input ports, this value is then overwritten
set_driving_cell -lib_cell $drive_cell  -pin $drive_cell_pin [all_inputs]

# Driver definition for clock inputs port on module level
# Note: 'set_drive 0' models an infinite drive, which is not realistic in
# post-clock tree mode
# Thus, use 'set_driving_cell', using a typical clock tree buffer
set_driving_cell -lib_cell L150_SCLK10  -pin Z [get_ports hs_core_clk]

# Load definition for data input ports on module level
set_load [expr 5 * [load_of [get_lib_pins starlib_lvt_10t/L150_SBUF10/A]]] [all_inputs]

# Load definition for data output ports on module level
set_load [expr 10 * [load_of [get_lib_pins starlib_lvt_10t/L150_SBUF10/A]]] [all_outputs]

# EoF DESIGN.ports.tcl
