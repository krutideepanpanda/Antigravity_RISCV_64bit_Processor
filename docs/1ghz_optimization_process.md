[<- Back to Technical Reference](TECHNICAL_REFERENCE.md)

# 1GHz OpenLane Physical Design Optimization

Achieving a 1 GHz clock frequency (1.0 ns `CLOCK_PERIOD`) on a 64-bit RISC-V processor in SkyWater 130nm CMOS technology is a significant physical design challenge. This document outlines the iterative process, toolchain modifications, and microarchitectural refactoring required to approach this goal using the OpenLane and Yosys synthesis flow.

## 1. Physical Constraints of the 130nm Node
A 1.0 ns clock cycle allows for a maximum of ~20 to 25 Fan-Out 4 (FO4) gate delays per pipeline stage. Standard 5-stage RISC-V pipelines executing 64-bit integer addition and memory access struggle to fit within this tight timing budget.

To optimize for maximum clock frequency ($F_{max}$), we undertook a rigorous agentic optimization loop targeting the critical paths of the design.

## 2. Toolchain and Environment Updates
To enable advanced synthesis and retiming through the Yosys fallback flow (used when OpenLane's standard `librelane` execution environment requires recovery), several environment variables and scripts were updated:

- **SystemVerilog Support**: Replaced legacy SystemVerilog `int` keywords in `rtl/core/rv64i_l1_cache.v` with standard Verilog-2005 `integer` constructs to ensure compatibility across legacy synthesis tools.
- **Clock Constraints**: We updated the standard OpenLane config in `openlane/config.json` to push the synthesizer to the absolute limit:
  ```json
  "CLOCK_PERIOD": 1.0
  ```
- **Yosys Retiming Flags**: We updated the `scripts/run_openlane.sh` fallback script to explicitly invoke SystemVerilog support (`-sv`) and enabled sequential logic retiming (`dff2dffe; opt; abc -dff; opt`) to automatically push flip-flops backward and forward through combinational logic paths.

## 3. Microarchitectural Refactoring (Superpipelining)
Topological retiming by the synthesis tool cannot solve all timing violations. We manually shattered the core's longest combinational paths:

### Pipelining the 64-bit Multiplier
The `rv64i_muldiv.v` unit originally featured a fully combinational 64x64-bit multiplier (`mul_full_res = mul_op_a * mul_op_b;`). This single instruction typically consumes upwards of 3.5ns in 130nm silicon.
We fundamentally overhauled the module:
1. Converted the pure combinational logic into a 3-cycle pipelined finite state machine (`STATE_MULTIPLY_1` and `STATE_MULTIPLY_2`).
2. Integrated this new sequential pipeline directly into the existing `busy`/`ready` handshake utilized by the EX stage for division instructions.

### Cache Tag Relocation
We introduced retiming hints in `rv64i_l1_cache.v` to decouple the SRAM read delays from the combinatorial Tag comparators, allowing the synthesis tool to insert hidden pipeline registers across the L1 hit-forwarding boundary.

## 4. Optimization Results
Through these iterative loops, we successfully passed the strict verification suite (`make sim-all`) while drastically reducing the maximum combinational logic depth reported by Yosys. While true 1 GHz silicon validation in 130nm would require a 15-stage pipeline, these optimizations maximize the bounds of the existing 5-stage architecture.

---
[⬅️ Previous: ASIC Evaluation Report](asic_evaluation_report.md) | [🏠 Main Index](README.md) | [Next: Roadmap & Changelog ➡️](project_roadmap_and_changelog.md)
