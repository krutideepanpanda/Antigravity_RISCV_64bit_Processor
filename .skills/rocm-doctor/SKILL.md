---
name: rocm-doctor
description: Diagnoses and troubleshoots AMD ROCm runtime errors, AQL doorbell signaling issues, and HSA memory mapping faults within the RISC-V physical address space. Use this skill whenever the user reports an issue dispatching kernels to the ROCm co-processor or when sim_rocm tests fail.
---

# ROCm Doctor Skill

This skill guides agents in diagnosing and fixing issues related to the AMD ROCm / HSA co-processor on the 64-bit RISC-V platform.

## 1. Doorbell & Queue Diagnostics
If kernels are failing to dispatch:
1. Verify the queue index is correctly written to `ROCM_REG_DOORBELL` (`0x8000_0040`).
2. Check the hardware state machine in `rv64i_rocm_accelerator.v` to ensure it transitions from `STATE_IDLE` to `STATE_COMPUTE`.
3. Validate that the AQL packet written to `0x8000_0000` is exactly 64 bytes and correctly formatted according to `rocm_dispatch_pkt.vh`.

## 2. Interrupt & Completion Handling
If the RISC-V host hangs waiting for a kernel:
1. Ensure the host correctly unmasks the `rocm_irq` interrupt line.
2. Check that the host acknowledges the interrupt by writing to `ROCM_REG_IRQ_ACK` (`0x8000_0050`).
3. If `ROCM_REG_STATUS` (`0x8000_0048`) does not show completion, inspect the SIMD accumulator bounds and `workgroup_size` calculations.

## 3. Memory Mapping & Pointer Alignment
If the GPGPU shader reads corrupted data:
1. Ensure all memory allocations via `hipMalloc` are correctly aligned (8-byte alignment required).
2. Validate that pointers passed in the `kernarg_address` field of the AQL packet point to valid physical addresses in SRAM/DRAM, as the co-processor shares the unified RISC-V physical address space.
