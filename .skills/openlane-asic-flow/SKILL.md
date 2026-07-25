---
name: openlane-asic-flow
description: Guides execution and evaluation of OpenLane / LibreLane ASIC synthesis, placement, CTS, routing, and GDSII generation targeting SkyWater 130nm (sky130A). Use this skill when synthesizing RTL, analyzing STA timing slack, checking area utilization, or running DRC/LVS.
---

# OpenLane ASIC Flow & Physical Design Skill

This skill automates the physical implementation of our 64-bit RISC-V processor (`asic_top.v`) into a synthesizable layout using LibreLane/OpenLane with the SkyWater 130nm open-source PDK (`sky130_fd_sc_hd`).

## 1. Environment & PDK Setup
Ensure the localized Python virtual environment is active and Homebrew tools are in `PATH`:
```bash
export PATH=/var/home/linuxbrew/.linuxbrew/bin:$PATH
source .venv/bin/activate
```

## 2. Executing ASIC Synthesis & Layout
Run the complete OpenLane flow using our configuration:
```bash
./scripts/run_openlane.sh
```
Or via make:
```bash
make openlane
```

## 3. Post-Layout Evaluation Checkpoints
After an OpenLane run completes, verify the following critical reports:
1. **GDSII Stream**: Check that `runs/*/results/final/gds/asic_top.gds` was created.
2. **Static Timing Analysis (STA)**: Inspect `runs/*/logs/routing/*.sta.rpt` to verify worst negative slack (WNS >= 0.00 ns) and calculate Fmax.
3. **Core Utilization & Cell Count**: Parse `runs/*/reports/synthesis/1-synthesis.stat.rpt` to determine total gate count, sequential vs. combinational cell ratio, and core die area.
4. **DRC / LVS Verification**: Check `runs/*/reports/signoff/drc.rpt` and `lvs.rpt` for 0 violations.
