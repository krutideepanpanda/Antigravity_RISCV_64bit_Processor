# Product Integration Guide

## How to use this IP in a real product

The Antigravity RISC-V 64-bit Processor is designed as a standalone hard macro or soft IP block that can be integrated into a larger System-on-Chip (SoC).

### 1. Integration into an SoC
To use this processor in a real product, you will typically instantiate `asic_top.v` within your SoC's top-level module. 
- **Memory Interfaces**: The processor provides standard `imem` (Instruction Memory) and `dmem` (Data Memory) ports. For a real product, these should be connected to a bus interconnect (such as AXI4 or TileLink) via a wrapper adapter, or directly to tightly-coupled SRAMs (TCMs) if predictability is prioritized.
- **Clock and Reset**: Ensure `clk` is stable and `rst` is asserted for at least 5 clock cycles during power-on.

### 2. Physical Design & Synthesis (Tape-Out)
This IP is verified for the SkyWater 130nm (sky130) Process Design Kit (PDK) using the OpenLane ASIC flow.
To synthesize this IP for a real ASIC:
1. Initialize the OpenLane environment.
2. Run `make openlane` to execute the synthesis, floorplanning, placement, and routing flow.
3. Review the generated GDSII files in `openlane/runs/`.
4. Ensure timing closures (setup/hold) are met at your target frequency (e.g., 100 MHz - 1 GHz depending on the node).

### 3. Verification & Compliance
Before taping out, ensure you run the full Verification Suite:
```bash
make sim-all
```
This runs compliance tests (ALU ops, branches, memory, data hazards, and real-life benchmarks like Fibonacci). In a real product scenario, you should also run the official RISC-V Architectural Testing framework (riscv-arch-test) against this core.

### 4. Software Toolchain
You do not need a custom compiler for this core. Because it is fully RV64I compliant, you can compile C/C++ code using the standard GCC or LLVM cross-compilers:
```bash
riscv64-unknown-elf-gcc -march=rv64i -mabi=lp64 -O3 firmware.c -o firmware.elf
```
Extract the `.text` and `.data` sections into a hex file and load it into the Boot ROM or Flash memory of your SoC.
