#-----------------------------------------------------------------------------#
# Template to setup timing constraints
#-----------------------------------------------------------------------------#
# Identify the tool used and set variables accordingly
if { ![info exists _pt] } { set _pt false }
if { ![info exists _dc] } { set _dc false }
if { ![info exists _icc] } { set _icc false }
if { ![info exists _inv] } { set _inv false }
if { ![info exists _gen] } { set _gen false }

#
if { [info exists synopsys_program_name] && \
           $synopsys_program_name == "dc_shell" } {
  puts "\n##### Applying constraints for Design Compiler-only part #####\n"
  set _dc true
} elseif { [info exists synopsys_program_name] && \
           $synopsys_program_name == "pt_shell" } {
  puts "\n##### Applying constraints for PrimeTime-only part #####\n"
  set _pt true
} elseif { [info exists synopsys_program_name] && \
           $synopsys_program_name == "icc_shell" } {
  puts "\n##### Applying constraints for IC Compiler-only part #####\n"
  set _icc true
} elseif { [regexp /opt/innovus.*   $tcl_library] } {
        puts "\n##### Applying constraints for Innovus-only part #####\n"
        set _inv true
} elseif {[regexp /opt/Genus.*     $tcl_library]} {
        puts "\n##### Applying constraints for Genus-only part #####\n"
        set _gen true

} else {
  puts "WARNING: Tool not recognized - constraints maybe not applied correctly. (IFX)"
}
#
if {$_pt} {
   set phase postlayout
} elseif { ![info exists phase] } {
  set phase prelayout
  puts "WARNING: No setup for phase variable - using default setting '$phase'. (IFX)"
}


#-----------------------------------------------------------------------------#
# Define the Library Defaults
#-----------------------------------------------------------------------------#
# set max_fanout_inport     <integer>;               ### Design Rule          # 
# set max_cap               <float>;                 ### Design Rule (< 2.0)  # 
# set design_max_transition <float>;                 ### Design Rule	      # 
# set WC_OP_COND           "<worst>";                ### OpCond  	      #
# set BC_OP_COND           "<best>";                 ### OpCond  	      #
# set WLOAD_LIB            "<lib>" ;                 ### WLM (min=max)	      #
# set WLOAD_MODEL          "<model">;                ### WLM (min=max)	      #
# set WLOAD_MODE           "<mode>";                 ### WLM (min=max)	      #
# set drive_cell           "<cell>";                 ### Env (no port loads)  #
# set drive_cell_pin       "<outpin>";               ### Env (no port loads)  #
# set GLOBAL_LOAD_CELL_PIN "<lib>/<cell>/<pin>";     ### Env (no fanout_load) #
# set typ_fanout            <integer>;               ### Env (no fanout_load) #
# set TYP_WIRELOAD          <float>;                 ### Env (no fanout_load) #
#-----------------------------------------------------------------------------#

#-----------------------------------------------------------------------------#
# Apply clock definitions
#-----------------------------------------------------------------------------#
source -echo -verbose constraints/${DESIGN}.clocks.tcl

#-----------------------------------------------------------------------------#
# Apply IO constraints
#-----------------------------------------------------------------------------#
source -echo -verbose constraints/${DESIGN}.ports.tcl

#-----------------------------------------------------------------------------#
# Apply multi cycle/ exceptions
#-----------------------------------------------------------------------------#
source -echo -verbose constraints/${DESIGN}.exceptions.tcl

# Further/general timing constraints

# Max transition
set_max_transition $design_max_transition [current_design]

# EoF DESIGN.tcl

