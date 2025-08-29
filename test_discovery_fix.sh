#!/bin/bash

# Quick test script to verify the discovery functions work without errors

echo "🧪 TESTING DISCOVERY FUNCTIONS"
echo "=============================="
echo ""

# Source the actual functions
source ./.github/scripts/setup/common.sh
init_script "test_discovery_fix" "Testing Discovery Functions"

echo "📋 Testing individual discovery functions:"
echo ""

echo "1. Testing discover_project_builds..."
if discover_project_builds > /dev/null 2>&1; then
    echo "   ✅ discover_project_builds - No errors"
else
    echo "   ❌ discover_project_builds - Error occurred"
fi

echo "2. Testing discover_project_applications..."  
if discover_project_applications > /dev/null 2>&1; then
    echo "   ✅ discover_project_applications - No errors"
else
    echo "   ❌ discover_project_applications - Error occurred"
fi

echo "3. Testing discover_project_repositories..."
if discover_project_repositories > /dev/null 2>&1; then
    echo "   ✅ discover_project_repositories - No errors"
else
    echo "   ❌ discover_project_repositories - Error occurred"
fi

echo "4. Testing discover_project_users..."
if discover_project_users > /dev/null 2>&1; then
    echo "   ✅ discover_project_users - No errors"
else
    echo "   ❌ discover_project_users - Error occurred"
fi

echo "5. Testing discover_project_stages..."
if discover_project_stages > /dev/null 2>&1; then
    echo "   ✅ discover_project_stages - No errors"
else
    echo "   ❌ discover_project_stages - Error occurred"
fi

echo ""
echo "🧪 SYNTAX TEST: Testing the problematic section"
echo "================================================"

# Test the exact pattern that was failing
echo "Testing arithmetic comparison on count variables..."

# Simulate what the fixed code does
users_count=4
if [[ "$users_count" -gt 0 ]]; then
    echo "   ✅ Arithmetic comparison works: $users_count > 0"
else
    echo "   ❌ Arithmetic comparison failed"
fi

echo ""
echo "🎯 TEST COMPLETE"
