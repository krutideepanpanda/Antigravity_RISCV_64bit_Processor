[<- Back to Technical Reference](TECHNICAL_REFERENCE.md)

# OpenLane RISC-V Processor Documentation Directory & Navigation Roadmap

Welcome to the technical documentation repository for the 64-bit RISC-V (RV64I) 5-stage pipelined processor ASIC IP block. This navigation directory serves as the institutional sitemap and engineering roadmap for systems architects, VLSI layout engineers, firmware developers, and verification leads exploring this repository.

All documentation in this directory adheres to strict institutional formatting standards, providing quantitative silicon signoff metrics, exact register-level interface definitions, and reproducible verification workflows without informal syntax or placeholder text.

---

## 1. Master System Specifications & Evaluation Reports

These primary engineering reports document the quantitative hardware parameters, physical layout metrics, and signoff verification results achieved in SkyWater 130nm CMOS technology:

| Document | Primary Audience | Scope & Key Technical Content |
| :--- | :--- | :--- |
| **[System Specification & Architecture Data Sheet](file:///home/bazzite/Antigravity_RISCV_64bit_Processor/docs/system_specification_and_architecture.md)** | Systems Architects & Chip Leads | Master institutional specification defining the RV64I ISA implementation, 5-stage microarchitecture, AMBA AXI4-Lite memory bridging, IP-XACT/FuseSoC packaging, and 100 MHz SkyWater 130nm signoff parameters. |
| **[ASIC Evaluation & Signoff Report](file:///home/bazzite/Antigravity_RISCV_64bit_Processor/docs/asic_evaluation_report.md)** | VLSI Physical Design Engineers | Complete physical layout evaluation documenting gate counts (18,348 standard cells, 3,262 DFFs), core area utilization (48.5% density on 0.5776 mm² core), clock tree synthesis (312 CTS buffers, 65ps skew), STA timing closure (+1.25ns setup WNS), routing wirelength (18.45 cm), via counts (42,510 vias), and DRC/LVS physical signoff. |
| **[Synthesis Optimization Report](synthesis_optimization_report.md)** | Synthesis & RTL Engineers | Comparative Yosys synthesis analysis contrasting standard hierarchical synthesis against flattened cross-boundary optimization (`-flatten; opt -full`), documenting our 2.91% reduction in sequential flip-flop overhead and wire bit reduction. |
| **[L1 Cache Performance Report](l1_cache_performance_report.md)** | Microarchitecture Engineers | Quantitative benchmark report demonstrating how our 8 KB 2-Way Set-Associative L1 cache with synchronous read hit forwarding increases Instructions Per Cycle (IPC) from 0.206 to 0.901 (a 4.37x architectural speedup). |
| **[1GHz Optimization Process](1ghz_optimization_process.md)** | VLSI Physical Design Engineers | Detailed documentation of the agentic openlane process, RTL superpipelining, topological retiming, and environment fixes applied to reach a 1.0ns clock period. |

---

## 2. Architectural Design & Codebase Guides

These reference guides explain the structure of the Verilog RTL source code, module hierarchy, and core engineering design choices:

| Document | Primary Audience | Scope & Key Technical Content |
| :--- | :--- | :--- |
| **[Codebase Architecture Guide](file:///home/bazzite/Antigravity_RISCV_64bit_Processor/docs/codebase_architecture.md)** | RTL & Verification Engineers | Structural walkthrough of the repository file tree, explaining all 14 Verilog RTL modules, pipeline stage interfaces (IF, ID, EX, MEM, WB), and Wishbone/SRAM registered boundaries in `asic_top`. |
| **[Design Philosophy & Principles](file:///home/bazzite/Antigravity_RISCV_64bit_Processor/docs/design_philosophy.md)** | Hardware Engineering Leads | Explains fundamental microarchitectural decisions: synchronous register boundaries, combinational RAW data forwarding vs. pipeline flushing, modular verification suites, and SkyWater 130nm cell density targets. |

---

## 3. SoC Integration & Co-Processing Manuals

These integration manuals provide necessary protocols and software runtimes for embedding the CPU core into larger System-on-Chip (SoC) architectures:

| Document | Primary Audience | Scope & Key Technical Content |
| :--- | :--- | :--- |
| **[SoC IP Integration Guide](file:///home/bazzite/Antigravity_RISCV_64bit_Processor/docs/ip_integration_guide.md)** | SoC & ASIC Integrators | Comprehensive integration manual providing pin descriptions, AXI4-Lite master/slave bridging instructions, IEEE 1685 IP-XACT XML integration (`rv64i_cpu_ip.xml`), and CAPI=2 FuseSoC core packaging (`rv64i_core.core`). |
| **[ROCm & HSA Co-Processing Guide](file:///home/bazzite/Antigravity_RISCV_64bit_Processor/docs/rocm_co_processing_guide.md)** | Firmware & Systems Engineers | Technical manual for the hardware kernel dispatch accelerator (`rv64i_rocm_accelerator.v`) and HIP-compatible C runtime library (`rocm_riscv_runtime.c`), detailing host-to-accelerator doorbell signaling and AQL packet structures. |

---

## 4. Operator Instructions & Project History

These operational documents guide developers through toolchain execution, verification testing, and historical project milestones:

| Document | Primary Audience | Scope & Key Technical Content |
| :--- | :--- | :--- |
| **[User & Operator Guide](file:///home/bazzite/Antigravity_RISCV_64bit_Processor/docs/user_guide.md)** | Developers & QA Engineers | Step-by-step instructions for building, syntax linting (`make lint`), running ISA simulation regression suites (`verif/scripts/test_driver.py`), executing OpenLane physical design (`scripts/run_openlane.sh`), and running performance benchmarks. |
| **[Roadmap & Institutional Changelog](file:///home/bazzite/Antigravity_RISCV_64bit_Processor/docs/project_roadmap_and_changelog.md)** | Engineering Management | Chronological record of architectural releases from `v1.0.0` to `v2.2.0`, tracking milestone achievements across RTL design, verification, compute co-processing, and ASIC tape-out signoff. |

---

## 5. Quick Reference: Recommended Reading Paths

* **For VLSI Layout Engineers**: Start with [asic_evaluation_report.md](file:///home/bazzite/Antigravity_RISCV_64bit_Processor/docs/asic_evaluation_report.md), then review [synthesis_optimization_report.md](file:///home/bazzite/Antigravity_RISCV_64bit_Processor/docs/synthesis_optimization_report.md) and [user_guide.md](file:///home/bazzite/Antigravity_RISCV_64bit_Processor/docs/user_guide.md) (Section 4: OpenLane Execution).
* **For SoC Integrators**: Start with [ip_integration_guide.md](file:///home/bazzite/Antigravity_RISCV_64bit_Processor/docs/ip_integration_guide.md), then review [system_specification_and_architecture.md](file:///home/bazzite/Antigravity_RISCV_64bit_Processor/docs/system_specification_and_architecture.md) and [rocm_co_processing_guide.md](file:///home/bazzite/Antigravity_RISCV_64bit_Processor/docs/rocm_co_processing_guide.md).
* **For RTL & Verification Engineers**: Start with [codebase_architecture.md](codebase_architecture.md), then review [design_philosophy.md](design_philosophy.md) and [l1_cache_performance_report.md](l1_cache_performance_report.md).

---
[🏠 Main Index](README.md) | [Next: System Specification & Architecture ➡️](system_specification_and_architecture.md)
