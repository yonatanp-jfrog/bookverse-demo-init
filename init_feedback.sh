#!/usr/bin/env bash

# Clean feedback wrapper for init_local.sh
# This script runs init_local.sh with clean progress feedback (no verbose curl)

set -e

# Set verbosity to 1 (feedback)
export VERBOSITY=1

# Run the init script and filter out:
# - Integer expression errors
# - Verbose curl output (lines starting with *, >, <, {, })
# - Progress bars and transfer stats
./init_local.sh 2>&1 | grep -v -E "(integer expression expected|\* |^> |^< |^\{ |^\} |^% Total|^  % |^  [0-9]+ |^[0-9]+ |^--:--:--|^[0-9]+ bytes|^[0-9]+ [0-9]+ |^[0-9]+ [0-9]+ [0-9]+ |^[0-9]+ [0-9]+ [0-9]+ [0-9]+ |^[0-9]+ [0-9]+ [0-9]+ [0-9]+ [0-9]+ |^[0-9]+ [0-9]+ [0-9]+ [0-9]+ [0-9]+ [0-9]+)" || true

# Check exit code and show result
if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Initialization completed successfully"
else
    echo ""
    echo "❌ Initialization failed with exit code $?"
    exit 1
fi
