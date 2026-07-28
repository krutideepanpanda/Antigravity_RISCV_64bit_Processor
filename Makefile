# ==============================================================================
# RISC-V 64-bit (RV64I) ASIC Development & OpenLane Tape-Out Makefile
# ==============================================================================

SHELL := /bin/bash
PATH  := $(CURDIR)/bin:/var/home/linuxbrew/.linuxbrew/bin:$(PATH)
VENV  := .venv/bin/activate

# RTL & Verification files
RTL_CORE_FILES := $(wildcard rtl/core/*.v)
RTL_TOP_FILES  := $(wildcard rtl/*.v) $(wildcard rtl/ip_block/*.v)
TB_FILES       := $(wildcard verif/*.v)
INC_DIR        := rtl/include

.PHONY: all help setup lint sim-all openlane fpga fpga-bitstream clean

all: help

help:
	@echo "===================================================================="
	@echo "  64-bit RISC-V (RV64I) ASIC & OpenLane Build System"
	@echo "===================================================================="
	@echo "  make setup      : Initialize toolchain and Python virtual environment"
	@echo "  make lint       : Run syntax checks and linting on Verilog RTL"
	@echo "  make sim-all    : Compile and execute the full RV64I test suite"
	@echo "  make openlane   : Execute OpenLane ASIC synthesis and GDSII generation"
	@echo "  make fpga       : One-click FPGA bitstream generation for Ultra96-V1"
	@echo "  make clean      : Remove build artifacts and simulation logs"
	@echo "===================================================================="

setup:
	@chmod +x scripts/setup_env.sh
	@./scripts/setup_env.sh

lint:
	@echo "--> Running Verilog syntax and lint checks..."
	@iverilog -g2012 -I $(INC_DIR) -t null $(RTL_CORE_FILES) $(RTL_TOP_FILES) && echo "[PASS] Icarus Verilog syntax check PASSED!"
	@if command -v verilator >/dev/null 2>&1; then \
		verilator --lint-only -Wall --top-module asic_top -Wno-MULTITOP -Wno-DECLFILENAME -Wno-UNOPTFLAT -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM -Wno-UNDRIVEN -I$(INC_DIR) $(RTL_CORE_FILES) $(RTL_TOP_FILES) && echo "[PASS] Verilator lint check PASSED!"; \
	fi

sim-all:
	@echo "--> Executing RV64I Verification & Compliance Suite..."
	@if [ -d ".venv" ]; then \
		source $(VENV) && /usr/bin/python3 verif/scripts/test_driver.py; \
	else \
		/usr/bin/python3 verif/scripts/test_driver.py; \
	fi

openlane:
	@echo "--> Starting OpenLane ASIC Synthesis & Layout Flow..."
	@chmod +x scripts/run_openlane.sh
	@if [ -d ".venv" ]; then \
		source $(VENV) && ./scripts/run_openlane.sh; \
	else \
		./scripts/run_openlane.sh; \
	fi

fpga fpga-bitstream:
	@echo "--> Launching One-Click Ultra96-V1 FPGA Implementation..."
	@$(MAKE) -C fpga bitstream

clean:
	@echo "--> Cleaning build and simulation files..."
	@rm -rf *.vcd *.out sim_build csrc *.log *.jou *.rpt *.stat fpga/build/
	@echo "Clean complete."
