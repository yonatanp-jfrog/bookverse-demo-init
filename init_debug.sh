#!/usr/bin/env bash

# Debug wrapper for init_local.sh
# This script runs init_local.sh with full debugging

set -e

# Set verbosity to 2 (debug)
export VERBOSITY=2

# Run the init script with debug mode
./init_local.sh
