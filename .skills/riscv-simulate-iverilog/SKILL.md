---
name: riscv-simulate-iverilog
description: Automates Verilog RTL compilation and testbench simulation using Icarus Verilog (iverilog) and vvp on Bazzite OS. Use this skill when verifying RISC-V processor modules, debugging pipeline hazards, or dumping VCD waveforms.
---

# RISC-V Icarus Verilog Simulation Skill

This skill provides standard workflows for compiling and simulating Verilog RTL for our 64-bit RISC-V processor (`RV64I`) using Homebrew tools on Bazzite OS.

## 1. Environment Requirements
Ensure the Homebrew binary directory is in `PATH`:
```bash
export PATH=/var/home/linuxbrew/.linuxbrew/bin:$PATH
```

## 2. Syntax & Lint Check
To verify clean Verilog-2012 syntax across all processor core and top modules:
```bash
iverilog -g2012 -I rtl/include -t null rtl/core/*.v rtl/*.v
```

## 3. Testbench Compilation & Execution
To compile a specific testbench (e.g., `tb_rv64i_cpu.v`) and run simulation with wave dumping:
```bash
# Compile
iverilog -g2012 -I rtl/include -o sim_build/tb_rv64i_cpu.out verif/tb_rv64i_cpu.v rtl/core/*.v rtl/*.v

# Execute
vvp sim_build/tb_rv64i_cpu.out
```

## 4. Waveform Inspection
If a simulation produces a `.vcd` dump, you can parse assertion logs or open waveforms in GTKWave:
```bash
grep -E "PASS|FAIL|ASSERT|ERROR" sim_build/simulation.log
```
