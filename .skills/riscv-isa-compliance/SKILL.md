---
name: riscv-isa-compliance
description: Guides automated execution of directed hex assembly tests for verifying 64-bit RISC-V (RV64I) ISA compliance. Use this skill when testing instruction categories (R, I, S, B, U, J, W) and asserting register/memory state signatures.
---

# RISC-V ISA Compliance Verification Skill

This skill outlines the testing methodology for validating that our 5-stage pipelined processor strictly complies with the RISC-V RV64I base integer instruction set specification.

## 1. Instruction Suite Categories
Our compliance verification suite evaluates 7 critical instruction categories:
1. **R-Type**: `add`, `sub`, `sll`, `slt`, `sltu`, `xor`, `srl`, `sra`, `or`, `and`
2. **I-Type**: `addi`, `slli`, `slti`, `sltiu`, `xori`, `srli`, `srai`, `ori`, `andi`, `lb`, `lh`, `lw`, `ld`, `lbu`, `lhu`, `lwu`, `jalr`
3. **S-Type**: `sb`, `sh`, `sw`, `sd`
4. **B-Type**: `beq`, `bne`, `blt`, `bge`, `bltu`, `bgeu`
5. **U-Type**: `lui`, `auipc`
6. **J-Type**: `jal`
7. **W-Type (32-bit word manipulation)**: `addw`, `subw`, `sllw`, `srlw`, `sraw`, `addiw`, `slliw`, `srliw`, `sraiw`

## 2. Running Automated Test Driver
To execute all directed machine-code hex tests and verify register file dumps (`x1`-`x31`):
```bash
export PATH=/var/home/linuxbrew/.linuxbrew/bin:$PATH
source .venv/bin/activate 2>/dev/null || true
python verif/scripts/test_driver.py --all
```

## 3. Debugging Compliance Failures
If an instruction fails compliance:
1. Inspect the PC address and failing instruction opcode in simulation output.
2. Check `rv64i_forwarding.v` to ensure ALU result forwarding is active for dependent instructions in EX and MEM stages.
3. Check `rv64i_hazard.v` for proper 1-cycle pipeline stalls on load-use data hazards.
