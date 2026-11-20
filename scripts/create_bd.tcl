# ----------------------------------------------------------------------------
# create_bd.tcl - Creates the Zynq UltraScale+ MPSoC block design for Kria K26
# ----------------------------------------------------------------------------

proc create_kria_bd {bd_name board_part} {
    create_bd_design $bd_name
    current_bd_design $bd_name

    set ps_cell [create_bd_cell -type ip -vlnv xilinx.com:ip:zynq_ultra_ps_e zynq_ultra_ps_e_0]

    if {$board_part ne ""} {
        apply_bd_automation -rule xilinx.com:bd_rule:zynq_ultra_ps_e -config {apply_board_preset "1"} $ps_cell
    }

    # Disable unused AXI master interfaces to leave a clean design
    set_property -dict [list \
        CONFIG.PSU__USE__M_AXI_GP0 {0} \
        CONFIG.PSU__USE__M_AXI_GP1 {0} \
        CONFIG.PSU__USE__M_AXI_GP2 {0} \
    ] $ps_cell

    # Ensure PL fabric clock 0 is enabled at 100 MHz
    set_property -dict [list \
        CONFIG.PSU__FPGA_PL0_ENABLE {1} \
        CONFIG.PSU__CRL_APB__PL0_REF_CTRL__FREQMHZ {100} \
    ] $ps_cell

    # Export pl_clk0 (100 MHz) and pl_resetn0 (active-low reset)
    set clk_port [create_bd_port -dir O -type clk pl_clk0]
    set rst_port [create_bd_port -dir O -type rst pl_resetn0]

    connect_bd_net [get_bd_pins zynq_ultra_ps_e_0/pl_clk0] $clk_port
    connect_bd_net [get_bd_pins zynq_ultra_ps_e_0/pl_resetn0] $rst_port

    validate_bd_design
    save_bd_design

    set bd_file [get_files [get_property FILE_NAME [current_bd_design]]]
    generate_target all $bd_file
    set wrapper_file [make_wrapper -files $bd_file -top]
    add_files -norecurse $wrapper_file

    puts "Block design '$bd_name' generated with wrapper: $wrapper_file"
    return $wrapper_file
}
