#!/usr/bin/env bash
set -e

echo "=========================================================="
echo "Initializing RISC-V 64-bit ASIC Environment on Bazzite OS"
echo "=========================================================="

# 1. Setup Linuxbrew PATH & Git fallback
export PATH=/var/home/linuxbrew/.linuxbrew/bin:$PATH
export HOMEBREW_GIT_PATH=/usr/bin/git

echo "--> Checking Homebrew EDA tools..."
for tool in icarus-verilog verilator yosys gh; do
    if ! brew list "$tool" &>/dev/null; then
        echo "Installing $tool via Homebrew..."
        brew install "$tool" || echo "Warning: Could not install $tool via brew. Ensure network connectivity."
    else
        echo "[$tool] is already installed in Homebrew."
    fi
done

# 2. Setup Python 3.14 Virtual Environment for OpenLane / LibreLane
echo "--> Setting up Python Virtual Environment (.venv)..."
if [ ! -d ".venv" ]; then
    /usr/bin/python3 -m venv .venv
    echo "Created virtual environment in .venv/"
fi

source .venv/bin/activate
echo "--> Upgrading pip and installing LibreLane / OpenLane / Volare..."
pip install --upgrade pip
pip install --upgrade librelane openlane volare || echo "Note: Using cached or system LibreLane/OpenLane installation."

echo "=========================================================="
echo "Environment setup complete! Run 'source .venv/bin/activate' to start."
echo "=========================================================="
