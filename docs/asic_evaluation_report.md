# ASIC Physical Design & Tape-Out Evaluation Report

**Project Name**: 64-bit RISC-V Pipelined Processor (`RV64I`)  
**Top-Level Module**: `asic_top`  
**Target Technology**: SkyWater 130nm CMOS Open-Source PDK (`sky130A` / `sky130_fd_sc_hd`)  
**EDA Toolchain**: OpenLane 2 / LibreLane / Yosys / OpenROAD / Magic  
**Date**: July 2026  

---

## 1. Executive Summary

This evaluation report documents the physical layout metrics, static timing analysis (STA), standard-cell utilization, power estimation, and DRC/LVS signoff verification for our 5-stage pipelined RV64I processor implemented in SkyWater 130nm technology.

| Metric | Target Specification | Achieved Signoff Value | Status |
| :--- | :--- | :--- | :--- |
| **PDK Target** | SkyWater 130nm (`sky130A`) | `sky130A` (`hd` library) | 🟢 Verified |
| **Clock Frequency ($F_{max}$)** | $\ge 50\text{ MHz}$ (Target period $20\text{ ns}$) | *Pending OpenLane Run* | 🟡 Pending |
| **Worst Negative Slack (WNS)** | $\ge 0.00\text{ ns}$ (No setup violations) | *Pending OpenLane Run* | 🟡 Pending |
| **Total Standard Cells** | $\approx 15,000 - 30,000$ cells | *Pending OpenLane Run* | 🟡 Pending |
| **Core Area Utilization** | $40\% - 60\%$ | *Pending OpenLane Run* | 🟡 Pending |
| **Total Die Area** | $\approx 1.5\text{ mm} \times 1.5\text{ mm}$ | *Pending OpenLane Run* | 🟡 Pending |
| **Design Rule Check (DRC)** | 0 Violations (Magic / KLayout) | *Pending OpenLane Run* | 🟡 Pending |
| **Layout vs. Schematic (LVS)** | 0 Violations (Netgen) | *Pending OpenLane Run* | 🟡 Pending |
| **GDSII Stream File** | Generated (`asic_top.gds`) | *Pending OpenLane Run* | 🟡 Pending |

---

## 2. Synthesis Breakdown (Yosys)

*To be populated from `runs/*/reports/synthesis/1-synthesis.stat.rpt` after ASIC layout generation.*

* **Sequential Cells (D-Flip-Flops)**: TBD
* **Combinational Logic Cells**: TBD
* **Total Wire Length**: TBD

---

## 3. Static Timing Analysis (STA)

*To be populated from `runs/*/logs/routing/*.sta.rpt`.*

* **Clock Period**: TBD
* **Setup Worst Negative Slack (WNS)**: TBD
* **Hold Worst Negative Slack (WNS)**: TBD
* **Max Clock Frequency ($F_{max}$)**: TBD

---

## 4. Power & Energy Estimation

*To be populated from OpenROAD power reports.*

* **Internal Power**: TBD mW
* **Switching Power**: TBD mW
* **Leakage Power**: TBD mW
* **Total Dynamic Power**: TBD mW

---

## 5. Tape-Out Signoff Conclusion

*Summary of final physical design signoff status once GDSII stream generation completes.*
