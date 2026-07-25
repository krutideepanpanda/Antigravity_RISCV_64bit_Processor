# RISC-V ASIC Processor User Guide & Quickstart

This guide walks you through compiling, simulating, and generating the GDSII layout for the 64-bit RISC-V processor on **Bazzite OS**.

---

## 1. Initial Environment Setup

Run the setup target to install Homebrew dependencies (`icarus-verilog`, `verilator`, `yosys`, `gh`) and initialize our Python virtual environment (`.venv`) containing OpenLane / LibreLane:

```bash
make setup
source .venv/bin/activate
```

---

## 2. RTL Syntax & Lint Verification

To ensure clean Verilog syntax without non-synthesizable constructs or accidental latches:

```bash
make lint
```
This executes `iverilog` syntax checks and `verilator --lint-only` rules across all files in `rtl/core/` and `rtl/`.

---

## 3. Running ISA Compliance Simulations

To execute the automated compliance simulation driver against all directed machine-code hex test programs:

```bash
make sim-all
```
The simulation test driver compiles `verif/tb_rv64i_cpu.v`, loads each hex test program into instruction memory, simulates processor execution for 2000 cycles, and verifies the final register file contents (`x1`-`x31`) against expected architectural states.

### Inspecting Waveforms
Simulation produces VCD waveform files in `sim_build/`. You can view them using GTKWave:
```bash
gtkwave sim_build/tb_rv64i_cpu.vcd
```

---

## 4. OpenLane ASIC Synthesis & GDSII Generation

To run the complete physical design flow targeting the **SkyWater 130nm PDK** (`sky130A`):

```bash
make openlane
```
This triggers `./scripts/run_openlane.sh`, executing:
1. **Synthesis** (Yosys) - Mapping Verilog RTL to SkyWater 130nm standard cells.
2. **Floorplan** (OpenROAD / OpenDP) - Core die sizing and I/O pin placement.
3. **Placement** (RePlAce / OpenDP) - Standard cell placement.
4. **Clock Tree Synthesis (CTS)** (TritonCTS) - Clock routing and buffering.
5. **Routing** (FastRoute / TritonRoute) - Global and detailed metal layer routing.
6. **Signoff** (Magic / Netgen / KLayout) - DRC and LVS physical verification and `asic_top.gds` generation.

---

## 5. Cleaning Build Artifacts

To remove simulation binaries, VCD logs, and temporary EDA outputs:
```bash
make clean
```
