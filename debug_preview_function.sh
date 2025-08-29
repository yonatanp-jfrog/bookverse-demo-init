#!/bin/bash

# Debug script to test the run_discovery_preview function in isolation

echo "🧪 TESTING run_discovery_preview() FUNCTION IN ISOLATION"
echo "=========================================================="
echo ""

# Source the required functions
source ./.github/scripts/setup/common.sh
source ./.github/scripts/setup/cleanup_project_based.sh

# Initialize like the main script does
init_script "debug_preview_function" "Testing Discovery Preview Function"

echo "📋 Environment Check:"
echo "  PROJECT_KEY: '${PROJECT_KEY}'"
echo "  JFROG_URL: '${JFROG_URL}'"
echo "  TEMP_DIR: '${TEMP_DIR}'"
echo ""

echo "🔧 Testing function call..."
echo ""

# Test the exact same call that's failing
set -x  # Enable debug output
preview_file=$(run_discovery_preview)
exit_code=$?
set +x  # Disable debug output

echo ""
echo "📊 RESULTS:"
echo "  Exit code: $exit_code"
echo "  Preview file: '$preview_file'"
echo ""

if [[ -n "$preview_file" && -f "$preview_file" ]]; then
    echo "📄 Preview file contents:"
    cat "$preview_file"
else
    echo "❌ Preview file not created or empty"
fi

echo ""
echo "🎯 Debug complete!"
