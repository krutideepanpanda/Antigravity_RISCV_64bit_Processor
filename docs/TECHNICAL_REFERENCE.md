# Technical Reference Manual

This document serves as the master index for the Antigravity RISC-V Processor and Agentic Framework documentation. It is designed for engineers, researchers, and developers who wish to understand the inner workings, architecture, and integration of the processor and its autonomous agents.

## Core Documentation

- [Codebase Architecture](codebase_architecture.md): Detailed breakdown of the repository structure, Verilog modules, and agent scripts.
- [System Specification and Architecture](system_specification_and_architecture.md): The overarching hardware specifications for the 64-bit RISC-V core.
- [Design Philosophy](design_philosophy.md): The core principles behind the Antigravity processor design.
- [Project Roadmap and Changelog](project_roadmap_and_changelog.md): Past milestones, current status, and future goals.

## Performance & Synthesis Reports

- [1 GHz Optimization Process](1ghz_optimization_process.md): Deep dive into the critical path optimizations to achieve a 1 GHz clock speed.
- [Synthesis Optimization Report](synthesis_optimization_report.md): Summary of the physical synthesis using OpenLane and Sky130 PDK.
- [ASIC Evaluation Report](asic_evaluation_report.md): Final evaluation metrics of the physical silicon implementation.
- [L1 Cache Performance Report](l1_cache_performance_report.md): Metrics and hit-rate analysis of the instruction and data caches.
- [Benchmark & Performance Report](BENCHMARK_REPORT.md): Analysis of real-life workloads on the processor.

## Integration & User Guides

- [User Guide](user_guide.md): Comprehensive guide on running the tools, simulations, and the web dashboard.
- [IP Integration Guide](ip_integration_guide.md): How to integrate the Antigravity RISC-V core into an SoC.
- [ROCm Co-Processing Guide](rocm_co_processing_guide.md): Experimental guidelines for co-processing with AMD ROCm.
- [Product Integration Guide](PRODUCT_GUIDE.md): Information on how to use this IP for a real product.

---
[Return to Main Readme](../README.md)
