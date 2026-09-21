#-----------------------------------------------------------------------------#
# Template to setup operating voltages on power nets
#-----------------------------------------------------------------------------#

# Adopt the voltage values based on the design requirements
puts "Information: Reading voltages from '[file tail [info script]]'. (IFX)"

if { 1 && [shell_is_in_topographical_mode] || $::synopsys_program_name=="icc_shell"} {
    foreach scn [current_scenario] {
        puts "Information: Reading voltages for scenario '${scn}'. (IFX)"
        if { ${scn} == "CLOCK" || ${scn} == "FUNCTIONAL_SLOW" || ${scn} == "SCN_SLOW"|| ${scn} == "SHIFT_SLOW" } {
           set_voltage -object_list {VDD} <VOLTAGE>
           set_voltage -object_list {VSS} 0.00
        } elseif { ${scn} == "FUNCTIONAL_FAST" || ${scn} == "SCN_FAST"|| ${scn} == "SHIFT_FAST" } {
           set_voltage -object_list {VDD} <VOLTAGE>
           set_voltage -object_list {VSS} 0.00
        }
    }
} else {
     set_voltage -object_list {VDD} <VOLTAGE>
     set_voltage -object_list {VSS} 0.00 
}
# EoF DESIGN.voltage.tcl
