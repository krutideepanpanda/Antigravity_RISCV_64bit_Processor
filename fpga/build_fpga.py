#!/usr/bin/env python3
# ============================================================================
# One-Click FPGA Build & Implementation Driver for Antigravity_RISCV_64bit_Processor
# Target: Avnet Ultra96-V1 (Zynq UltraScale+ XCZU3EG)
# ============================================================================

import os
import sys
import subprocess
import shutil
import glob

def find_vivado():
    """Locates the Xilinx Vivado executable in PATH or standard installation directories."""
    vivado_path = shutil.which("vivado")
    if vivado_path:
        return vivado_path

    # Common Xilinx installation locations on Linux
    search_paths = [
        "/opt/Xilinx/Vivado/*/bin/vivado",
        "/tools/Xilinx/Vivado/*/bin/vivado",
        os.path.expanduser("~/Xilinx/Vivado/*/bin/vivado"),
        "/home/linuxbrew/Xilinx/Vivado/*/bin/vivado",
        "/usr/local/Xilinx/Vivado/*/bin/vivado"
    ]
    for pattern in search_paths:
        matches = sorted(glob.glob(pattern), reverse=True)
        if matches:
            return matches[0]
    return None

def print_install_instructions():
    print("----------------------------------------------------------------------------")
    print(" [ERROR] Xilinx Vivado was not found in PATH or standard installation dirs.")
    print("----------------------------------------------------------------------------")
    print(" To synthesize and generate bitstreams for the Avnet Ultra96-V1 FPGA board,")
    print(" you need Xilinx Vivado (ML Standard or WebPACK edition - FREE for XCZU3EG):")
    print("")
    print(" 1. Download Xilinx Unified Installer from: https://www.xilinx.com/support/download.html")
    print(" 2. Install Vivado 2020.2 or newer to a standard path (e.g. /opt/Xilinx or ~/Xilinx)")
    print(" 3. Source the environment settings before running this build script:")
    print("    $ source /opt/Xilinx/Vivado/2020.2/settings64.sh")
    print("    $ make fpga-bitstream")
    print("----------------------------------------------------------------------------")

def main():
    print("============================================================================")
    print(" Antigravity_RISCV_64bit_Processor: One-Click Ultra96-V1 FPGA Implementation Flow")
    print("============================================================================")

    # Change working directory to repo root
    repo_root = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
    os.chdir(repo_root)

    # Ensure build directory exists
    os.makedirs("fpga/build", exist_ok=True)

    # Locate Vivado
    vivado_cmd = find_vivado()
    if not vivado_cmd:
        print_install_instructions()
        sys.exit(1)

    print(f"--> Found Xilinx Vivado at: {vivado_cmd}")
    print("--> Launching Vivado in batch mode with fpga/scripts/run_impl.tcl...")
    print("----------------------------------------------------------------------------")

    cmd = [
        vivado_cmd,
        "-mode", "batch",
        "-source", "fpga/scripts/run_impl.tcl",
        "-notrace",
        "-nojournal",
        "-log", "fpga/build/vivado.log"
    ]

    try:
        res = subprocess.run(cmd, check=True)
        print("----------------------------------------------------------------------------")
        print("[SUCCESS] FPGA implementation completed successfully!")
        print("Bitstream location: fpga/build/antigravity_riscv_64bit_processor.bit")
        print("Hardware Platform:  fpga/build/antigravity_riscv_64bit_processor.xsa")
        print("----------------------------------------------------------------------------")
    except subprocess.CalledProcessError as e:
        print(f"[ERROR] Vivado implementation failed with exit code {e.returncode}.")
        print("Check log file at fpga/build/vivado.log for details.")
        sys.exit(e.returncode)

if __name__ == "__main__":
    main()
