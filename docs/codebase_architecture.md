# Codebase & Signal Interface Specification

This document provides the complete structural hierarchy, signal interface specifications, and pipeline register descriptions for the 64-bit RISC-V processor (`RV64I`).

---

## 1. Module Hierarchy

```text
asic_top.v                       # Synthesizable ASIC wrapper with registered I/O bus
└── rv64i_cpu.v                  # Top-level processor core wrapper
    ├── rv64i_if.v               # Stage 1: Instruction Fetch (PC, Adder, Muxes)
    ├── rv64i_id.v               # Stage 2: Instruction Decode
    │   ├── rv64i_regfile.v      # 32x64-bit general purpose register file
    │   ├── rv64i_imm_gen.v      # Immediate generator (I, S, B, U, J sign-extensions)
    │   └── rv64i_control.v      # Main control unit & ALU opcode decoder
    ├── rv64i_ex.v               # Stage 3: Execute
    │   └── rv64i_alu.v          # 64-bit ALU & 32-bit word manipulation unit
    ├── rv64i_mem.v              # Stage 4: Memory Access & Byte alignment
    ├── rv64i_wb.v               # Stage 5: Writeback selection mux
    ├── rv64i_forwarding.v       # Data hazard forwarding logic
    └── rv64i_hazard.v           # Pipeline stall and branch flush logic
```

---

## 2. Core Signal Interface (`rv64i_cpu`)

| Signal Name | Direction | Width | Description |
| :--- | :--- | :--- | :--- |
| `clk` | Input | 1 bit | System clock (positive-edge triggered) |
| `rst` | Input | 1 bit | Asynchronous active-high system reset |
| `imem_addr` | Output | 64 bits | Instruction memory read address (PC) |
| `imem_rdata` | Input | 32 bits | Raw 32-bit instruction read from instruction memory |
| `dmem_addr` | Output | 64 bits | Data memory read/write address |
| `dmem_wdata` | Output | 64 bits | Formatted data to be written to memory |
| `dmem_we` | Output | 1 bit | Data memory write enable flag |
| `dmem_re` | Output | 1 bit | Data memory read enable flag |
| `dmem_be` | Output | 8 bits | Data memory byte-enable mask (`11111111` for 64-bit doubleword) |
| `dmem_rdata` | Input | 64 bits | Data read from memory |

---

## 3. Pipeline Registers & Control Signals

### IF/ID Pipeline Register
* **Inputs**: `if_pc`, `if_pc_plus4`, `imem_rdata`
* **Outputs**: `id_pc`, `id_pc_plus4`, `id_instr`
* **Control**: Stalled when `hazard_stall` is asserted; Flushed to NOP (`32'h00000013`) when `hazard_flush` is asserted.

### ID/EX Pipeline Register
* **Inputs**: Decoded control signals, `rs1_data`, `rs2_data`, `imm`, `rs1_addr`, `rs2_addr`, `rd_addr`, `id_pc`, `id_pc_plus4`
* **Outputs**: `ex_reg_write`, `ex_mem_to_reg`, `ex_mem_write`, `ex_mem_read`, `ex_alu_op`, `ex_alu_src`, `ex_branch`, `ex_jump`, etc.

### EX/MEM Pipeline Register
* **Inputs**: `alu_result`, `ex_rs2_data`, `ex_rd_addr`, `branch_target`, `branch_taken`, control flags
* **Outputs**: `mem_alu_result`, `mem_wdata`, `mem_rd_addr`, `mem_reg_write`, `mem_mem_to_reg`, `mem_mem_write`, `mem_mem_read`

### MEM/WB Pipeline Register
* **Inputs**: `mem_alu_result`, `dmem_rdata_formatted`, `mem_rd_addr`, `mem_reg_write`, `mem_mem_to_reg`
* **Outputs**: `wb_alu_result`, `wb_mem_rdata`, `wb_rd_addr`, `wb_reg_write`, `wb_mem_to_reg`

---

## 4. Immediate Generator Coding (`rv64i_imm_gen`)

The immediate generator extracts and sign-extends bits from the 32-bit instruction opcode according to RV64I instruction formats:
* **I-Type**: `{{52{instr[31]}}, instr[31:20]}`
* **S-Type**: `{{52{instr[31]}}, instr[31:25], instr[11:7]}`
* **B-Type**: `{{51{instr[31]}}, instr[31], instr[7], instr[30:25], instr[11:8], 1'b0}`
* **U-Type**: `{{32{instr[31]}}, instr[31:12], 12'b0}`
* **J-Type**: `{{43{instr[31]}}, instr[31], instr[19:12], instr[20], instr[30:21], 1'b0}`
