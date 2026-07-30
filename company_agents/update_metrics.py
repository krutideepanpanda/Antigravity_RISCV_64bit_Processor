#!/usr/bin/env python3
import json
import subprocess
import re
import os

METRICS_FILE = "company_agents/processor_metrics.json"
CONFIG_FILE = "openlane/config.json"

def update_metrics():
    metrics = {
        "Core Architecture": "64-bit RISC-V (RV64I)",
        "Pipeline Depth": "5-Stage (IF, ID, EX, MEM, WB)",
        "Target Node (PDK)": "Unknown",
        "Target Clock Frequency": "Unknown",
        "Die Area (µm²)": "Unknown",
        "Core Area (µm²)": "Unknown",
        "Benchmark Suite": "Unknown",
        "Total Executed Cycles": "Unknown",
        "Algorithmic Instructions": "Unknown",
        "Pipeline Fetched Instrs": "Unknown",
        "Algorithmic CPI": "Unknown",
        "Algorithmic IPC": "Unknown",
        "Pipeline CPI": "Unknown",
        "Pipeline IPC": "Unknown",
        "Load-Use Stalls": "Unknown",
        "RAW Forwarding Stalls": "Unknown",
        "Branch Control Hazards": "Unknown",
        "Pipeline Startup/Drain": "Unknown",
        "Ideal 1-Cycle Datapath": "Unknown"
    }
    
    # 1. Parse OpenLane Config
    try:
        with open(CONFIG_FILE, "r") as f:
            config = json.load(f)
            metrics["Target Node (PDK)"] = config.get("PDK", "sky130A")
            
            period_ns = config.get("CLOCK_PERIOD", 0)
            if period_ns > 0:
                freq_mhz = 1000 / period_ns
                if freq_mhz >= 1000:
                    metrics["Target Clock Frequency"] = f"{freq_mhz/1000:.1f} GHz ({period_ns}ns)"
                else:
                    metrics["Target Clock Frequency"] = f"{freq_mhz:.0f} MHz ({period_ns}ns)"
            
            die_area = config.get("DIE_AREA", [0,0,0,0])
            width = die_area[2] - die_area[0]
            height = die_area[3] - die_area[1]
            metrics["Die Area (µm²)"] = f"{width} x {height}"
            
            core_area = config.get("CORE_AREA", [0,0,0,0])
            cwidth = core_area[2] - core_area[0]
            cheight = core_area[3] - core_area[1]
            metrics["Core Area (µm²)"] = f"{cwidth} x {cheight}"
    except Exception as e:
        print(f"Error reading config: {e}")

    # 2. Run Benchmark to get IPC
    try:
        result = subprocess.run(["python3", "verif/scripts/run_benchmarks.py"], capture_output=True, text=True)
        out = result.stdout
        
        match_bench = re.search(r"Benchmark Suite\s*:\s*(.*?)$", out, re.M)
        if match_bench: metrics["Benchmark Suite"] = match_bench.group(1).strip()
        
        match_tot_cyc = re.search(r"Total Executed Cycles\s*:\s*(.*?)$", out, re.M)
        if match_tot_cyc: metrics["Total Executed Cycles"] = match_tot_cyc.group(1).strip()
        
        match_algo_inst = re.search(r"Algorithmic Instructions\s*:\s*(.*?)$", out, re.M)
        if match_algo_inst: metrics["Algorithmic Instructions"] = match_algo_inst.group(1).strip()
        
        match_pipe_inst = re.search(r"Pipeline Fetched Instrs\s*:\s*(.*?)$", out, re.M)
        if match_pipe_inst: metrics["Pipeline Fetched Instrs"] = match_pipe_inst.group(1).strip()

        match_algo_cpi = re.search(r"Algorithmic CPI\s*:\s*([\d\.]+)", out)
        if match_algo_cpi: metrics["Algorithmic CPI"] = match_algo_cpi.group(1)

        match_algo_ipc = re.search(r"Algorithmic IPC\s*:\s*([\d\.]+)", out)
        if match_algo_ipc: metrics["Algorithmic IPC"] = match_algo_ipc.group(1)
        
        match_pipe_cpi = re.search(r"Pipeline CPI \(w/ drain\)\s*:\s*([\d\.]+)", out)
        if match_pipe_cpi: metrics["Pipeline CPI"] = match_pipe_cpi.group(1)
            
        match_pipe_ipc = re.search(r"Pipeline IPC \(w/ drain\)\s*:\s*([\d\.]+)", out)
        if match_pipe_ipc: metrics["Pipeline IPC"] = match_pipe_ipc.group(1)
        
        match_load = re.search(r"Load-Use Hazard Stalls\s*:\s*(.*?)$", out, re.M)
        if match_load: metrics["Load-Use Stalls"] = match_load.group(1).strip()
        
        match_raw = re.search(r"ALU RAW Forwarding Stalls\s*:\s*(.*?)$", out, re.M)
        if match_raw: metrics["RAW Forwarding Stalls"] = match_raw.group(1).strip()
        
        match_branch = re.search(r"Branch Control Hazards\s*:\s*(.*?)$", out, re.M)
        if match_branch: metrics["Branch Control Hazards"] = match_branch.group(1).strip()
        
        match_drain = re.search(r"Pipeline Startup/Drain\s*:\s*(.*?)$", out, re.M)
        if match_drain: metrics["Pipeline Startup/Drain"] = match_drain.group(1).strip()
        
        match_ideal = re.search(r"Ideal 1-Cycle Datapath\s*:\s*(.*?)$", out, re.M)
        if match_ideal: metrics["Ideal 1-Cycle Datapath"] = match_ideal.group(1).strip()
            
    except Exception as e:
        print(f"Error running benchmark: {e}")

    # 3. Write to JSON
    with open(METRICS_FILE, "w") as f:
        json.dump(metrics, f, indent=2)
    print(f"Extremely comprehensive metrics updated successfully.")

if __name__ == "__main__":
    update_metrics()
