# ----------------------------------------------------------------------------
# config.tcl - shared project settings, sourced by the other scripts.
# Do not run this file directly.
# ----------------------------------------------------------------------------

set PROJECT_NAME "uart"
set TOP_MODULE   "kria_top"
set SIM_TOP      "tb_top"

set ROOT_DIR     [file normalize [file join [file dirname [info script]] ..]]
set RTL_DIR      [file join $ROOT_DIR rtl]
set SIM_DIR      [file join $ROOT_DIR sim]
set XDC_DIR      [file join $ROOT_DIR constraints]
set IP_DIR       [file join $ROOT_DIR ip]
set BUILD_DIR    [file join $ROOT_DIR build]
set PROJECT_DIR  [file join $BUILD_DIR vivado]

# Kria K26 SOM FPGA part
set FPGA_PART "xck26-sfvc784-2LV-c"

# Detect Kria board part if available
set BOARD_PART ""
set avail_boards [get_board_parts -quiet *kv260_som*]
if {[llength $avail_boards] > 0} {
    set BOARD_PART [lindex $avail_boards end]
} else {
    set avail_k26 [get_board_parts -quiet *k26c*]
    if {[llength $avail_k26] > 0} {
        set BOARD_PART [lindex $avail_k26 end]
    }
}

set TARGET_LANGUAGE    "Verilog"
set SIMULATOR_LANGUAGE "Mixed"

# Number of parallel jobs for synthesis / implementation.
set BUILD_JOBS 8

# Collect all matching files in a directory, ignoring missing dirs/files.
proc collect_sources {dir patterns} {
    set files {}
    if {![file isdirectory $dir]} {
        return $files
    }
    foreach pattern $patterns {
        foreach f [glob -nocomplain -directory $dir $pattern] {
            lappend files $f
        }
    }
    return [lsort -unique $files]
}

set RTL_SOURCES [collect_sources $RTL_DIR {*.v *.sv *.vhd}]
set SIM_SOURCES [collect_sources $SIM_DIR {*.v *.sv *.vhd}]
set XDC_SOURCES [collect_sources $XDC_DIR {*.xdc}]
set IP_SOURCES  [collect_sources $IP_DIR  {*.xci}]
