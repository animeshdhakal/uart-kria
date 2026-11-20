source [file join [file dirname [info script]] config.tcl]
source [file join [file dirname [info script]] create_bd.tcl]

create_project $PROJECT_NAME $PROJECT_DIR \
    -part $FPGA_PART \
    -force

if {$BOARD_PART ne ""} {
    puts "Using board part: $BOARD_PART"
    set_property board_part $BOARD_PART [current_project]
} else {
    puts "No specific board part selected, using FPGA part: $FPGA_PART"
}

set_property target_language    $TARGET_LANGUAGE    [current_project]
set_property simulator_language $SIMULATOR_LANGUAGE [current_project]

# Create Kria Block Design to provide PL clock (100 MHz) and active-low reset
create_kria_bd "system" $BOARD_PART

if {[llength $RTL_SOURCES] > 0} {
    add_files -fileset sources_1 $RTL_SOURCES
} else {
    puts "WARNING: no RTL sources found in $RTL_DIR"
}

if {[llength $XDC_SOURCES] > 0} {
    add_files -fileset constrs_1 $XDC_SOURCES
} else {
    puts "WARNING: no constraints found in $XDC_DIR"
}

if {[llength $IP_SOURCES] > 0} {
    add_files -fileset sources_1 $IP_SOURCES
}

if {[llength $SIM_SOURCES] > 0} {
    add_files -fileset sim_1 $SIM_SOURCES
    set_property top $SIM_TOP [get_filesets sim_1]
    update_compile_order -fileset sim_1
    set_property -name {xsim.simulate.runtime} -value {-all} -objects [get_filesets sim_1]
}

set_property top $TOP_MODULE [current_fileset]
update_compile_order -fileset sources_1

puts "Project created: [file join $PROJECT_DIR $PROJECT_NAME.xpr]"
puts "Top module:      $TOP_MODULE"
puts "RTL files:       [llength $RTL_SOURCES]"
puts "Sim files:       [llength $SIM_SOURCES]"
puts "XDC files:       [llength $XDC_SOURCES]"
puts "IP files:        [llength $IP_SOURCES]"
