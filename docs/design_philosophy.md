# RISC-V 64-bit (RV64I) Design Philosophy & Methodology

This document outlines the architectural trade-offs, design methodology, and synthesis principles guiding the implementation of our 64-bit RISC-V processor (`RV64I`) and its physical implementation in the open-source **SkyWater 130nm PDK** (`sky130A`).

---

## 1. Why the 5-Stage Pipeline?

When designing a processor for ASIC synthesis, the choice of microarchitecture dictates clock frequency ($F_{max}$), silicon die area, and dynamic power dissipation. We evaluated three primary microarchitectures:

| Microarchitecture | $F_{max}$ Potential | Area & Gate Count | Control Complexity | Hazard Handling |
| :--- | :--- | :--- | :--- | :--- |
| **Single-Cycle** | Very Low (long critical path) | Minimal sequential cells | Trivial | None needed |
| **Multi-Cycle** | Moderate | Low | FSM-based (high routing) | None needed |
| **5-Stage Pipelined** | **High (short stage paths)** | **Balanced** | **Modular & Clean** | **Full Forwarding + Stalls** |

We selected the **5-stage pipelined microarchitecture** (Fetch, Decode, Execute, Memory, Writeback) because it achieves an optimal balance between high clock frequency and modest standard-cell area in 130nm CMOS technology. By breaking instruction execution into 5 clean stages separated by synchronous D-flip-flop registers (`IF/ID`, `ID/EX`, `EX/MEM`, `MEM/WB`), we limit the critical path in any single cycle to a 64-bit ALU operation or a single memory access.

---

## 2. Synthesizable Verilog & RTL Best Practices

To ensure 100% bug-free synthesis in open-source EDA tools (Yosys, OpenLane, Verilator), we enforce strict RTL coding standards:
1. **Synchronous Design**: All sequential state elements use positive-edge triggered D-flip-flops (`always @(posedge clk or posedge rst)`). Asynchronous active-high reset is uniformly applied across all registers.
2. **Zero Latch Rule**: Combinational logic blocks (`always @(*)`) must assign defaults to every output signal before conditional evaluation (`if-else` or `case`) to prevent unintended transparent latches during Yosys synthesis.
3. **No Non-Synthesizable Constructs**: Core modules strictly avoid `#` delays, `initial` blocks for state initialization, and non-synthesizable file I/O. Memory contents for verification are loaded exclusively in simulation testbenches (`tb_rv64i_cpu.v`).
4. **Clean Register File Hardwiring**: Register `x0` is hardwired to `64'b0` both in read multiplexing and by ignoring writes to address `5'b00000`, preventing logic waste during standard cell synthesis.

---

## 3. Hazard Resolution Strategy

Pipelining introduces data and control hazards that must be resolved without corrupting processor state:

### A. Data Hazard Forwarding (Bypassing)
Instead of stalling the pipeline for every data dependency, our `rv64i_forwarding.v` module monitors destination register addresses in the `MEM` and `WB` stages. If an upcoming ALU operand matches an active writeback register ($R_{d} \neq 0$), the forwarding unit dynamically routes the ALU result or memory read data directly into the Execute stage multiplexers.

### B. Load-Use Data Hazard Stalls
When an instruction depends on the result of a load instruction (`ld`, `lw`, etc.) immediately preceding it, data cannot be forwarded in time because memory read data is only available at the end of the `MEM` stage. Our `rv64i_hazard.v` module detects load-use conditions in `ID/EX` and asserts a 1-cycle stall by:
* Freezing the Program Counter (`PC` write enable = 0).
* Freezing the `IF/ID` pipeline register.
* Injecting a synchronous NOP (`bubble`) into the `ID/EX` pipeline register.

### C. Control Hazard Flushes (Branch & Jump)
When a conditional branch (`beq`, `bne`, etc.) is taken or an unconditional jump (`jal`, `jalr`) executes, instructions already fetched into the `IF` and `ID` stages are incorrect. Upon branch decision in the Execute stage, the hazard unit asserts flush signals, clearing `IF/ID` and `ID/EX` pipeline registers on the next clock edge.

---

## 4. Design for Testability (DFT) & ASIC Tape-Out

For our OpenLane physical tape-out (`asic_top.v`), we wrap the processor core with a clean, synchronous SRAM/Wishbone-compatible bus interface. All top-level pins are registered to ensure predictable I/O timing delays and eliminate hold-time violations during OpenLane routing and Static Timing Analysis (STA).
