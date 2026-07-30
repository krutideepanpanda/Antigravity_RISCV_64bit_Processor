[<- Back to Technical Reference](TECHNICAL_REFERENCE.md)

# RISC-V ASIC Processor User Guide & Quickstart

This guide walks you through compiling, linting, simulating, and generating the GDSII layout for our 64-bit RISC-V pipelined processor on **Bazzite OS**. It also details our custom automated skills for developer and agent workflows.

---

## 1. Initial Environment Setup

Before running simulation or ASIC synthesis, install the required EDA toolchains (`icarus-verilog`, `verilator`, `yosys`, `gh`) and initialize the isolated Python virtual environment containing OpenLane 2 and LibreLane:

```bash
make setup
source .venv/bin/activate
```

---

## 2. RTL Syntax & Lint Verification

To ensure clean Verilog syntax without non-synthesizable constructs, transparent latches, or combinational loops:

```bash
make lint
```

**What this step does:**
* Invokes `iverilog` syntax checking across all RTL files in [rtl/core/](file:///home/bazzite/Antigravity_RISCV_64bit_Processor/rtl/core) and [asic_top.v](file:///home/bazzite/Antigravity_RISCV_64bit_Processor/rtl/asic_top.v).
* Executes `verilator --lint-only -Wall` static analysis rules to catch width mismatches, unassigned outputs, and implicit wire declarations.

---

## 3. Running ISA Compliance Simulations (`make sim-all`)

To execute the automated compliance simulation driver against all directed machine-code hex test programs:

```bash
make sim-all
```

**Step-by-Step Execution Flow:**
1. **Driver Invocation**: `Makefile` calls our automated Python test runner, [test_driver.py](file:///home/bazzite/Antigravity_RISCV_64bit_Processor/verif/scripts/test_driver.py).
2. **Test Discovery**: The driver scans [verif/tests/hex/](file:///home/bazzite/Antigravity_RISCV_64bit_Processor/verif/tests/hex) for machine-code hex test suites (`test_alu_ops.hex`, `test_branches.hex`, `test_forwarding_hazards.hex`, `test_memory.hex`, `test_word_ops.hex`).
3. **Compilation & Execution**: For each test, `test_driver.py` compiles the CPU core along with the master verification testbench [tb_rv64i_cpu.v](file:///home/bazzite/Antigravity_RISCV_64bit_Processor/verif/tb_rv64i_cpu.v) using `iverilog -o sim_build/sim.vvp`. It then executes the simulation with `vvp`.
4. **Architectural State Verification**: The CPU executes 2000 clock cycles and dumps final general-purpose register states (`x1`-`x31`) into verification log files. The driver compares these register states against expected gold reference signatures, reporting a green `PASSED` status for 100% ISA compliance.

### Inspecting Waveforms
Simulation produces VCD waveform files in `sim_build/`. You can view them using GTKWave:
```bash
gtkwave sim_build/tb_rv64i_cpu.vcd
```

---

## 4. OpenLane ASIC Synthesis & GDSII Generation (`make openlane`)

To run the complete physical design flow targeting the **SkyWater 130nm PDK** (`sky130A`):

```bash
make openlane
```

**Step-by-Step Execution Flow:**
1. **Script Execution**: Triggers [run_openlane.sh](file:///home/bazzite/Antigravity_RISCV_64bit_Processor/scripts/run_openlane.sh), which configures the Python toolchain wrapper and invokes OpenLane 2 using the configuration in [openlane/config.json](file:///home/bazzite/Antigravity_RISCV_64bit_Processor/openlane/config.json) and pad floorplan in [openlane/pin_order.cfg](file:///home/bazzite/Antigravity_RISCV_64bit_Processor/openlane/pin_order.cfg).
2. **Synthesis (Yosys)**: Maps synthesizable RTL in [asic_top.v](file:///home/bazzite/Antigravity_RISCV_64bit_Processor/rtl/asic_top.v) and [rtl/core/](file:///home/bazzite/Antigravity_RISCV_64bit_Processor/rtl/core) to SkyWater 130nm High-Density (`sky130_fd_sc_hd`) standard cells.
3. **Floorplanning (OpenROAD / OpenDP)**: Establishes an $800\,\mu\text{m} \times 800\,\mu\text{m}$ die boundary, places peripheral I/O pins, and inserts power distribution network (PDN) metal stripes.
4. **Placement (RePlAce / OpenDP)**: Performs global and detailed placement of standard cells within the core boundary.
5. **Clock Tree Synthesis (TritonCTS)**: Synthesizes a low-skew clock distribution network driving all sequential D-flip-flops.
6. **Routing (FastRoute / TritonRoute)**: Completes global and detailed multi-layer metal routing (Met1-Met5) with antenna diode insertion.
7. **Signoff Verification (Magic / Netgen / OpenROAD)**: Executes DRC rule checking in Magic (0 violations), netlist LVS comparison in Netgen (0 violations), post-layout STA timing closure ($F_{max} = 100\text{ MHz}$), and generates the final fabrication layout `asic_top.gds`.

---

## 5. Using Custom Agent Skills (`.skills/`)

Our repository bundles custom domain skills in [.skills/](file:///home/bazzite/Antigravity_RISCV_64bit_Processor/.skills) that enable developers and AI agents to execute specific EDA workflows autonomously:

| Skill Name | Directory Path | Purpose & Capabilities |
| :--- | :--- | :--- |
| `riscv-simulate-iverilog` | [.skills/riscv-simulate-iverilog/](file:///home/bazzite/Antigravity_RISCV_64bit_Processor/.skills/riscv-simulate-iverilog) | Compiles and simulates individual RISC-V assembly test programs using Icarus Verilog (`iverilog`) and `vvp`. Analyzes waveform output (`tb_rv64i_cpu.vcd`) to debug instruction timing, forwarding paths, and memory alignment. |
| `riscv-isa-compliance` | [.skills/riscv-isa-compliance/](file:///home/bazzite/Antigravity_RISCV_64bit_Processor/.skills/riscv-isa-compliance) | Orchestrates the complete automated ISA compliance test suite via [test_driver.py](file:///home/bazzite/Antigravity_RISCV_64bit_Processor/verif/scripts/test_driver.py). Validates integer arithmetic, branch decisions, load/store hazards, and register file write-through behavior against architectural reference states. |
| `openlane-asic-flow` | [.skills/openlane-asic-flow/](file:///home/bazzite/Antigravity_RISCV_64bit_Processor/.skills/openlane-asic-flow) | Automates execution of the SkyWater 130nm OpenLane physical design flow via [run_openlane.sh](file:///home/bazzite/Antigravity_RISCV_64bit_Processor/scripts/run_openlane.sh). Parses log artifacts to report gate counts, DFF utilization, clock frequency $F_{max}$, setup/hold timing slack, and DRC/LVS cleanliness. |

---

## 6. Cleaning Build Artifacts

To remove simulation binaries, VCD waveform dumps, python cache directories, and temporary EDA physical synthesis runs:
```bash
make clean
```


---
[⬅️ Previous: ROCm Co-Processing](rocm_co_processing_guide.md) | [🏠 Main Index](README.md) | [Next: L1 Cache Performance ➡️](l1_cache_performance_report.md)
