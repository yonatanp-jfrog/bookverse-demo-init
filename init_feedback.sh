#!/usr/bin/env bash

# Feedback wrapper for init_local.sh
# This script runs init_local.sh with progress feedback

set -e

# Set verbosity to 1 (feedback)
export VERBOSITY=1

# Run the init script with feedback
./init_local.sh
