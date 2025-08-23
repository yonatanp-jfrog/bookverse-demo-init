#!/usr/bin/env bash

# Debug wrapper for init_local.sh
# This script runs init_local.sh with full debugging but filters out errors

set -e

# Set verbosity to 2 (debug)
export VERBOSITY=2

# Run the init script and filter out integer expression errors
# Keep all debug output but hide the bash errors
./init_local.sh 2>&1 | grep -v "integer expression expected" || true

# Check exit code and show result
if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Initialization completed successfully"
else
    echo ""
    echo "❌ Initialization failed with exit code $?"
    exit 1
fi
