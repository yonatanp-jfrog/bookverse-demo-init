#!/usr/bin/env bash

# Silent wrapper for init_local.sh
# This script runs init_local.sh with complete silence

set -e

# Set verbosity to 0 (silent)
export VERBOSITY=0

# Run the init script and redirect all output to /dev/null
# Only show errors (exit code 1)
./init_local.sh > /dev/null 2>&1

# Check exit code and show result
if [ $? -eq 0 ]; then
    echo "✅ Initialization completed successfully"
else
    echo "❌ Initialization failed with exit code $?"
    exit 1
fi
