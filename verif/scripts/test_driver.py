#!/usr/bin/env python3
"""
RV64I Verification Suite Test Driver
Compiles RTL and testbench using Icarus Verilog, runs simulation across all hex test files,
and reports pass/fail statistics with an ASCII summary table.
"""
import os
import sys
import subprocess
import glob

def find_executable(cmd):
    # Check workspace bin directory first
    workspace_cmd = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), "bin", cmd)
    if os.path.exists(workspace_cmd):
        if cmd == "iverilog":
            lib_dir = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), "lib", "ivl")
            return [workspace_cmd, "-B", lib_dir]
        return [workspace_cmd]

    # Check if standard command works
    try:
        res = subprocess.run([cmd, "-V"], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        if res.returncode == 0:
            return [cmd]
    except Exception:
        pass

    # Check linuxbrew path with ELF interpreter fallback for immutable container environments
    brew_cmd = f"/var/home/linuxbrew/.linuxbrew/bin/{cmd}"
    if os.path.exists(brew_cmd):
        try:
            res = subprocess.run([brew_cmd, "-V"], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            if res.returncode == 0:
                return [brew_cmd]
        except Exception:
            pass
        if os.path.exists("/lib64/ld-linux-x86-64.so.2"):
            return ["/lib64/ld-linux-x86-64.so.2", brew_cmd]
    return [cmd]

def run_test_suite():
    print("============================================================================")
    print(" 64-bit RISC-V (RV64I) 5-Stage Pipelined Processor - ISA Verification Suite")
    print("============================================================================")

    # 1. Ensure test hex files exist
    os.makedirs("verif/waves", exist_ok=True)
    if not os.path.exists("verif/tests/test_alu_ops.hex") or not os.path.exists("verif/tests/test_xgfx_hdmi.hex"):
        print("--> Generating machine-code test hex suites...")
        subprocess.run([sys.executable, "verif/scripts/generate_tests.py"], check=True)

    # 2. Find Icarus Verilog tools
    iverilog_cmd = find_executable("iverilog")
    vvp_cmd = find_executable("vvp")

    # 3. Compile RTL + Testbench
    print("--> Compiling Verilog RTL and testbench with Icarus Verilog...")
    rtl_files = glob.glob("rtl/core/*.v") + glob.glob("rtl/ip_block/*.v") + ["rtl/asic_top.v", "verif/tb_rv64i_cpu.v"]
    compile_cmd = iverilog_cmd + ["-g2012", "-I", "rtl/include", "-o", "verif/sim_tb", "-s", "tb_rv64i_cpu"] + rtl_files
    
    res = subprocess.run(compile_cmd, capture_output=True, text=True)
    if res.returncode != 0:
        print("[ERROR] Compilation failed!")
        print(res.stderr)
        sys.exit(1)
    print("--> Compilation successful! Simulation binary created at verif/sim_tb")
    print("----------------------------------------------------------------------------")

    # 4. Run tests
    test_files = sorted(glob.glob("verif/tests/*.hex"))
    if not test_files:
        print("[ERROR] No hex test files found in verif/tests/")
        sys.exit(1)

    passed = 0
    failed = 0
    results = []

    for test_file in test_files:
        test_name = os.path.basename(test_file).replace(".hex", "")
        sim_cmd = vvp_cmd + ["verif/sim_tb", f"+test_file={test_file}"]
        
        sim_res = subprocess.run(sim_cmd, capture_output=True, text=True)
        out = sim_res.stdout + sim_res.stderr

        if "=== TEST PASSED ===" in out and sim_res.returncode == 0:
            status = "PASS"
            passed += 1
        else:
            status = "FAIL"
            failed += 1

        results.append((test_name, status))
        print(f"[{status}] Test Suite: {test_name}")
        if status == "FAIL":
            print(f"       Log Output:\n{out.strip()}")

    print("----------------------------------------------------------------------------")
    print(f" Verification Summary: {passed} PASSED | {failed} FAILED | Total: {len(test_files)}")
    print("============================================================================")

    if failed > 0:
        sys.exit(2)
    else:
        print("[SUCCESS] ALL ISA COMPLIANCE & VERIFICATION TESTS PASSED SUCCESSFULLY!")
        sys.exit(0)

if __name__ == "__main__":
    run_test_suite()
