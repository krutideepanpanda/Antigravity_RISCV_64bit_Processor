#!/usr/bin/env bash
set -e

echo "=========================================================="
echo "Starting OpenLane / Yosys ASIC Synthesis Flow"
echo "=========================================================="

# 1. Setup Environment Variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="$(dirname "$SCRIPT_DIR")"
export PATH="$WORKSPACE_DIR/bin:/var/home/linuxbrew/.linuxbrew/bin:$PATH"
export HOMEBREW_GIT_PATH=/usr/bin/git

# 2. Activate Virtual Environment if available
if [ -d "$WORKSPACE_DIR/.venv" ]; then
    echo "--> Activating Python virtual environment (.venv)..."
    source "$WORKSPACE_DIR/.venv/bin/activate"
fi

# 3. Execute OpenLane or Yosys Synthesis
if command -v openlane &> /dev/null && [ "$1" != "--yosys" ] && [ "$1" != "--yosys-only" ]; then
    echo "--> Running OpenLane flow on openlane/config.json..."
    openlane openlane/config.json || {
        echo "--> OpenLane encountered an issue, executing standalone Yosys synthesis..."
        yosys -p "read_verilog -I rtl/include rtl/core/*.v rtl/asic_top.v; synth -top asic_top; stat"
    }
else
    echo "--> Executing standalone Yosys synthesis..."
    yosys -p "read_verilog -I rtl/include rtl/core/*.v rtl/asic_top.v; synth -top asic_top; stat"
fi

echo "=========================================================="
echo "ASIC Synthesis Execution Complete!"
echo "=========================================================="
