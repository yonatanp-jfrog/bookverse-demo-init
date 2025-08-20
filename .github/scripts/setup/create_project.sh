#!/bin/bash
set -e
echo "Creating BookVerse Project..."
# This script uses the JFrog CLI, which must be configured with the admin token
jf project create bookverse --display-name="BookVerse"
