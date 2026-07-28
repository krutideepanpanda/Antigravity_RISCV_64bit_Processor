# ============================================================================
# Xilinx Design Constraints (XDC) for Avnet Ultra96-V1 FPGA Board
# Target Part: XCZU3EG-1SBVA484E (Zynq UltraScale+ MPSoC ZU3EG ATEG)
# ============================================================================

# ----------------------------------------------------------------------------
# Clock & Reset Constraints
# ----------------------------------------------------------------------------
# 100 MHz System Clock (From PS FCLK0 or High-Speed Header PL_CLK)
set_property PACKAGE_PIN D7 [get_ports sys_clk]
set_property IOSTANDARD LVCMOS18 [get_ports sys_clk]
create_clock -period 10.000 -name sys_clk [get_ports sys_clk]

# 25.175 MHz Pixel Clock (VGA / HDMI Mode 0 Text Generator Clock)
set_property PACKAGE_PIN F8 [get_ports pix_clk]
set_property IOSTANDARD LVCMOS18 [get_ports pix_clk]
create_clock -period 39.722 -name pix_clk [get_ports pix_clk]

# Active-Low Asynchronous Resets
set_property PACKAGE_PIN D8 [get_ports rst_n]
set_property IOSTANDARD LVCMOS18 [get_ports rst_n]

set_property PACKAGE_PIN F7 [get_ports pix_rst_n]
set_property IOSTANDARD LVCMOS18 [get_ports pix_rst_n]

# ----------------------------------------------------------------------------
# HDMI / Video Display Engine CMOS Parallel Interface (Bank 65 / 66 GPIO Header)
# ----------------------------------------------------------------------------
# Synchronization & Display Enable Signals
set_property PACKAGE_PIN G6 [get_ports vd_de]
set_property IOSTANDARD LVCMOS18 [get_ports vd_de]

set_property PACKAGE_PIN G5 [get_ports vd_hsync]
set_property IOSTANDARD LVCMOS18 [get_ports vd_hsync]

set_property PACKAGE_PIN A6 [get_ports vd_vsync]
set_property IOSTANDARD LVCMOS18 [get_ports vd_vsync]

# RGB888 Pixel Data Bus (VD_DATA[23:0])
set_property PACKAGE_PIN A7 [get_ports {vd_data[0]}]
set_property IOSTANDARD LVCMOS18 [get_ports {vd_data[0]}]

set_property PACKAGE_PIN B6 [get_ports {vd_data[1]}]
set_property IOSTANDARD LVCMOS18 [get_ports {vd_data[1]}]

set_property PACKAGE_PIN C6 [get_ports {vd_data[2]}]
set_property IOSTANDARD LVCMOS18 [get_ports {vd_data[2]}]

set_property PACKAGE_PIN C7 [get_ports {vd_data[3]}]
set_property IOSTANDARD LVCMOS18 [get_ports {vd_data[3]}]

set_property PACKAGE_PIN A8 [get_ports {vd_data[4]}]
set_property IOSTANDARD LVCMOS18 [get_ports {vd_data[4]}]

set_property PACKAGE_PIN B8 [get_ports {vd_data[5]}]
set_property IOSTANDARD LVCMOS18 [get_ports {vd_data[5]}]

set_property PACKAGE_PIN C8 [get_ports {vd_data[6]}]
set_property IOSTANDARD LVCMOS18 [get_ports {vd_data[6]}]

set_property PACKAGE_PIN D9 [get_ports {vd_data[7]}]
set_property IOSTANDARD LVCMOS18 [get_ports {vd_data[7]}]

set_property PACKAGE_PIN E9 [get_ports {vd_data[8]}]
set_property IOSTANDARD LVCMOS18 [get_ports {vd_data[8]}]

set_property PACKAGE_PIN F9 [get_ports {vd_data[9]}]
set_property IOSTANDARD LVCMOS18 [get_ports {vd_data[9]}]

set_property PACKAGE_PIN G9 [get_ports {vd_data[10]}]
set_property IOSTANDARD LVCMOS18 [get_ports {vd_data[10]}]

set_property PACKAGE_PIN A9 [get_ports {vd_data[11]}]
set_property IOSTANDARD LVCMOS18 [get_ports {vd_data[11]}]

set_property PACKAGE_PIN B9 [get_ports {vd_data[12]}]
set_property IOSTANDARD LVCMOS18 [get_ports {vd_data[12]}]

set_property PACKAGE_PIN C9 [get_ports {vd_data[13]}]
set_property IOSTANDARD LVCMOS18 [get_ports {vd_data[13]}]

set_property PACKAGE_PIN A10 [get_ports {vd_data[14]}]
set_property IOSTANDARD LVCMOS18 [get_ports {vd_data[14]}]

set_property PACKAGE_PIN B10 [get_ports {vd_data[15]}]
set_property IOSTANDARD LVCMOS18 [get_ports {vd_data[15]}]

set_property PACKAGE_PIN C10 [get_ports {vd_data[16]}]
set_property IOSTANDARD LVCMOS18 [get_ports {vd_data[16]}]

set_property PACKAGE_PIN D10 [get_ports {vd_data[17]}]
set_property IOSTANDARD LVCMOS18 [get_ports {vd_data[17]}]

set_property PACKAGE_PIN E10 [get_ports {vd_data[18]}]
set_property IOSTANDARD LVCMOS18 [get_ports {vd_data[18]}]

set_property PACKAGE_PIN F10 [get_ports {vd_data[19]}]
set_property IOSTANDARD LVCMOS18 [get_ports {vd_data[19]}]

set_property PACKAGE_PIN G10 [get_ports {vd_data[20]}]
set_property IOSTANDARD LVCMOS18 [get_ports {vd_data[20]}]

set_property PACKAGE_PIN A11 [get_ports {vd_data[21]}]
set_property IOSTANDARD LVCMOS18 [get_ports {vd_data[21]}]

set_property PACKAGE_PIN B11 [get_ports {vd_data[22]}]
set_property IOSTANDARD LVCMOS18 [get_ports {vd_data[22]}]

set_property PACKAGE_PIN C11 [get_ports {vd_data[23]}]
set_property IOSTANDARD LVCMOS18 [get_ports {vd_data[23]}]

# ----------------------------------------------------------------------------
# AXI & Memory Bus Interfaces (Routed internally in Zynq PS-PL Interconnect)
# ----------------------------------------------------------------------------
# Note: In IP Integrator (Block Design), imem_* and dmem_* interfaces are mapped
# directly to Zynq PS S_AXI_HP0_FPD and S_AXI_HPM0_FPD ports without physical I/O pads.
