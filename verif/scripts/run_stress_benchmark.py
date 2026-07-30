#!/usr/bin/env python3
import os
import sys
import subprocess
import glob
import re

def find_executable(cmd):
    workspace_cmd = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), "bin", cmd)
    if os.path.exists(workspace_cmd):
        if cmd == "iverilog":
            lib_dir = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), "lib", "ivl")
            return [workspace_cmd, "-B", lib_dir]
        return [workspace_cmd]
    try:
        res = subprocess.run([cmd, "-V"], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        if res.returncode == 0: return [cmd]
    except Exception: pass
    brew_cmd = f"/var/home/linuxbrew/.linuxbrew/bin/{cmd}"
    if os.path.exists(brew_cmd):
        try:
            res = subprocess.run([brew_cmd, "-V"], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            if res.returncode == 0: return [brew_cmd]
        except Exception: pass
        if os.path.exists("/lib64/ld-linux-x86-64.so.2"): return ["/lib64/ld-linux-x86-64.so.2", brew_cmd]
    return [cmd]

def run():
    print("============================================================================")
    print(" Memory Stress Benchmark (Automated Verification)")
    print("============================================================================")

    iverilog_cmd = find_executable("iverilog")
    vvp_cmd = find_executable("vvp")

    print("--> Compiling Verilog RTL and testbench...")
    rtl_files = glob.glob("rtl/core/*.v") + glob.glob("rtl/ip_block/*.v") + ["rtl/asic_top.v", "verif/tb_rv64i_cpu.v"]
    compile_cmd = iverilog_cmd + ["-g2012", "-I", "rtl/include", "-o", "verif/sim_tb", "-s", "tb_rv64i_cpu"] + rtl_files
    res = subprocess.run(compile_cmd, capture_output=True, text=True)
    if res.returncode != 0:
        print("[ERROR] Compilation failed!")
        sys.exit(1)

    test_file = "verif/tests/hex/test_memory_stress.hex"
    print(f"--> Running simulation on {test_file}")
    sim_cmd = vvp_cmd + ["verif/sim_tb", f"+test_file={test_file}"]
    sim_res = subprocess.run(sim_cmd, capture_output=True, text=True)
    out = sim_res.stdout + sim_res.stderr

    if "=== TEST PASSED ===" not in out:
        print("[ERROR] Simulation failed!")
        sys.exit(1)

    cycle_match = re.search(r"=== TEST PASSED === at cycle (\d+)", out)
    if cycle_match:
        total_cycles = int(cycle_match.group(1))
        # 21 instructions in test_memory_stress.hex
        algorithmic_instrs = 21
        cpi = total_cycles / algorithmic_instrs
        ipc = algorithmic_instrs / total_cycles
        print(f" Total Executed Cycles   : {total_cycles}")
        print(f" Algorithmic Instructions: {algorithmic_instrs}")
        print(f" Calculated CPI          : {cpi:.4f}")
        print(f" Calculated IPC          : {ipc:.4f}")
        print("--> Stress Benchmark completed successfully!")
    else:
        print("[ERROR] Could not extract cycle count.")

if __name__ == "__main__":
    run()
