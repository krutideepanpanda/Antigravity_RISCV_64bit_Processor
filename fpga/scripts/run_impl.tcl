# ============================================================================
# Vivado Batch Synthesis & Implementation TCL Script for Antigravity_RISCV_64bit_Processor
# Target: Avnet Ultra96-V1 (XCZU3EG-1SBVA484E)
# ============================================================================

puts "============================================================================"
puts " Antigravity_RISCV_64bit_Processor: Automated Vivado FPGA Implementation for Ultra96-V1"
puts "============================================================================"

# Set target device and directories
set part "xczu3eg-sbva484-1-e"
set proj_name "openlane_ultra96"
set build_dir "fpga/build"

# Ensure clean build directory exists
file mkdir $build_dir
cd $build_dir

# Create project in memory / build dir
create_project -force $proj_name . -part $part

# Set HDL target language
set_property target_language Verilog [current_project]
set_property default_lib work [current_project]

puts "--> [1/5] Importing Verilog RTL and XDC Constraint files..."
# Import all Verilog RTL sources
add_files -fileset sources_1 [glob ../../rtl/include/*.vh]
add_files -fileset sources_1 [glob ../../rtl/core/*.v]
add_files -fileset sources_1 [glob ../../rtl/ip_block/*.v]
add_files -fileset sources_1 [glob ../../rtl/rocm/*.v]
add_files -fileset sources_1 [glob ../../rtl/asic_top.v]

# Import XDC constraints
add_files -fileset constrs_1 ../constraints/ultra96_v1.xdc

# Define top module
set_property top asic_top [current_fileset]
update_compile_order -fileset sources_1

puts "--> [2/5] Running Synthesis (synth_design for $part)..."
synth_design -top asic_top -part $part -flatten_hierarchy rebuilt

puts "--> [3/5] Generating Post-Synthesis Reports..."
report_utilization -file post_synth_utilization.rpt
report_timing_summary -file post_synth_timing.rpt

puts "--> [4/5] Running Placement & Routing (opt_design, place_design, route_design)..."
opt_design
place_design
route_design

puts "--> Generating Post-Route Timing and Utilization Reports..."
report_utilization -file post_route_utilization.rpt
report_timing_summary -file post_route_timing.rpt
report_power -file post_route_power.rpt

puts "--> [5/5] Generating FPGA Bitstream & Hardware Platform..."
# Write bitstream (.bit)
write_bitstream -force antigravity_riscv_64bit_processor.bit
# Write hardware platform (.xsa / .hwh for PYNQ and Vitis)
write_hw_platform -fixed -include_bit -force antigravity_riscv_64bit_processor.xsa

puts "============================================================================"
puts " [SUCCESS] Ultra96-V1 Bitstream generated: fpga/build/antigravity_riscv_64bit_processor.bit"
puts " [SUCCESS] Hardware Platform generated:   fpga/build/antigravity_riscv_64bit_processor.xsa"
puts "============================================================================"
exit
