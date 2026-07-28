# ============================================================================
# FPGA Implementation Makefile for Antigravity_RISCV_64bit_Processor (Avnet Ultra96-V1)
# ============================================================================

PYTHON ?= /usr/bin/python3
BUILD_DIR ?= build

.PHONY: all bitstream synth clean help

all: bitstream

bitstream:
	@echo "--> Launching one-click Ultra96-V1 FPGA bitstream generation..."
	$(PYTHON) build_fpga.py

synth:
	@echo "--> Running Vivado Synthesis only..."
	$(PYTHON) build_fpga.py

clean:
	@echo "--> Cleaning FPGA build artifacts..."
	rm -rf $(BUILD_DIR) *.log *.jou *.str .Xil/

help:
	@echo "============================================================================"
	[echo] " Antigravity_RISCV_64bit_Processor FPGA Build Targets:"
	@echo "   make bitstream  - Run full synthesis, P&R, and generate bitstream (.bit)"
	@echo "   make clean      - Remove temporary build directories and logs"
	@echo "============================================================================"
