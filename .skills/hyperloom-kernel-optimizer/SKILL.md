---
name: hyperloom-kernel-optimizer
description: Guides execution of AMD Hyperloom (TraceLens, Arbor, GEAK) to profile and optimize AQL kernel dispatches and SIMD execution on the RISC-V ROCm co-processor. Use this skill when the user asks to optimize ROCm workloads, reduce kernel execution time, or analyze GPU bottlenecks.
---

# Hyperloom Kernel Optimizer Skill

This skill empowers agents to autonomously optimize ROCm and HIP workloads for the 64-bit RISC-V co-processor architecture using AMD Hyperloom.

## 1. Trace Profiling with TraceLens
Use the TraceLens tool to parse simulation VCD dumps and AQL dispatch packets.
- Identify suboptimal `workgroup_size` configurations in the AQL packets.
- Pinpoint register spilling or excessive execution cycles in `ROCM_REG_STATUS`.

## 2. Kernel Optimization with Arbor & GEAK
When performance bottlenecks are found:
1. Invoke the Arbor cognitive engine to generate candidate kernel modifications.
2. Adjust the C runtime driver code in `software/rocm_runtime/` (e.g. modifying `hipLaunchKernelGGL` grid dimensions).
3. Re-compile using the ROCm Core SDK.
4. Execute `make sim-all` to run the updated kernel in the Verilog testbench.

## 3. Feedback Loop
Analyze the new cycle counts from `run_benchmarks.py`. Continue the iterative loop until the optimization targets are reached.
