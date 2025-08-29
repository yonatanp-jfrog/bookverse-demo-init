#!/bin/bash

# Test script to verify the configuration loading fix

echo "🧪 TESTING CONFIGURATION FIX"
echo "============================"
echo ""

# Test the exact same logic as cleanup_project_based.sh
echo "📋 Step 1: Source common.sh (like the old broken version)"
unset PROJECT_KEY  # Make sure it's not set
source ./.github/scripts/setup/common.sh

echo "PROJECT_KEY after sourcing common.sh only: '${PROJECT_KEY:-EMPTY}'"
echo ""

# Test with init_script (like the fixed version)
echo "📋 Step 2: Call init_script (like the fixed version)"
unset PROJECT_KEY  # Reset again
source ./.github/scripts/setup/common.sh
init_script "test_script" "Testing Configuration Loading"

echo "PROJECT_KEY after init_script: '${PROJECT_KEY:-EMPTY}'"
echo ""

echo "🎯 TEST RESULTS:"
if [[ -n "$PROJECT_KEY" ]]; then
    echo "✅ SUCCESS: PROJECT_KEY is now loaded: '$PROJECT_KEY'"
    echo "✅ The configuration fix works!"
else
    echo "❌ FAILURE: PROJECT_KEY is still empty"
    echo "❌ The configuration fix did not work"
fi

echo ""
echo "🔍 SAFETY TEST: Repository filtering simulation"
echo "==============================================="

if [[ -n "$PROJECT_KEY" ]]; then
    echo "Filter would be: contains('$PROJECT_KEY')"
    echo "✅ This will correctly filter for bookverse repositories only"
else
    echo "Filter would be: contains('')"
    echo "🚨 This would match ALL repositories (the catastrophic bug!)"
fi
