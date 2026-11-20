source [file join [file dirname [info script]] config.tcl]

set project_file [file join $PROJECT_DIR $PROJECT_NAME.xpr]

if {![file exists $project_file]} {
    puts "ERROR: no project found at $project_file"
    puts "       run scripts/create_project.tcl first"
    exit 1
}

open_project $project_file

reset_run synth_1
launch_runs synth_1 -jobs $BUILD_JOBS
wait_on_run synth_1

if {[get_property PROGRESS [get_runs synth_1]] ne "100%"} {
    puts "ERROR: synthesis failed"
    puts [get_property STATUS [get_runs synth_1]]
    exit 1
}
puts "Synthesis complete: [get_property STATUS [get_runs synth_1]]"

reset_run impl_1
launch_runs impl_1 -to_step write_bitstream -jobs $BUILD_JOBS
wait_on_run impl_1

if {[get_property PROGRESS [get_runs impl_1]] ne "100%"} {
    puts "ERROR: implementation failed"
    puts [get_property STATUS [get_runs impl_1]]
    exit 1
}
puts "Implementation complete: [get_property STATUS [get_runs impl_1]]"

set bit_files [glob -nocomplain [file join $PROJECT_DIR $PROJECT_NAME.runs impl_1 *.bit]]
if {[llength $bit_files] > 0} {
    set bit_path [lindex $bit_files 0]
    puts "Bitstream: $bit_path"

    # Generate .bit.bin using bootgen for Kria Linux (xmutil / fpgautil)
    set bif_file [file join $PROJECT_DIR "bitstream.bif"]
    set bin_file [file rootname $bit_path].bit.bin

    set fp [open $bif_file w]
    puts $fp "all:\n{\n    \[destination_device = pl\] $bit_path\n}"
    close $fp

    puts "Generating Kria bitstream bin with bootgen: $bin_file"
    if {[catch {exec bootgen -image $bif_file -arch zynqmp -process_bitstream bin -w -o $bin_file} msg]} {
        puts "WARNING: bootgen execution failed: $msg"
    } else {
        puts "Kria bitstream bin created: $bin_file"
    }
} else {
    puts "WARNING: no bitstream found in impl_1 run directory"
}

close_project
