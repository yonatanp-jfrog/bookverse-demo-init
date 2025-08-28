#!/usr/bin/env bash

echo "🔍 Validating Cleanup Script Fix"
echo "================================="

# Test 1: Syntax validation
echo "Test 1: Script syntax validation"
if bash -n ./cleanup.sh 2>/dev/null; then
    echo "  ✅ No bash syntax errors"
else
    echo "  ❌ Bash syntax errors found"
    exit 1
fi

# Test 2: Validate the make_api_call function doesn't have eval issues
echo ""
echo "Test 2: Checking for problematic eval commands"
if grep -q "eval.*curl" ./cleanup.sh; then
    echo "  ❌ Found problematic eval commands (this was the source of HTTP 000 errors)"
    exit 1
else
    echo "  ✅ No eval commands found in curl calls"
fi

# Test 3: Validate API endpoints are back to original working format
echo ""
echo "Test 3: Checking API endpoint configurations"

# Extract the resource configurations
repos_config=$(grep -A1 '"repositories")' ./cleanup.sh | tail -1 | sed 's/.*echo "//' | sed 's/" ;;.*//')
users_config=$(grep -A1 '"users")' ./cleanup.sh | tail -1 | sed 's/.*echo "//' | sed 's/" ;;.*//')

echo "  Repositories config: $repos_config"
echo "  Users config: $users_config"

# Check if they match the original working format
if [[ "$repos_config" == *"/artifactory/api/repositories?project="* ]] && [[ "$repos_config" == *"|jf|"* ]]; then
    echo "  ✅ Repositories endpoint restored to original working format"
else
    echo "  ❌ Repositories endpoint format incorrect"
    exit 1
fi

if [[ "$users_config" == *"/artifactory/api/security/users"* ]] && [[ "$users_config" == *"|jf|"* ]]; then
    echo "  ✅ Users endpoint restored to original working format"  
else
    echo "  ❌ Users endpoint format incorrect"
    exit 1
fi

# Test 4: Check curl command structure
echo ""
echo "Test 4: Validating curl command structure"

# Look for the curl commands in the make_api_call function
curl_lines=$(grep -A10 "code=\$(curl" ./cleanup.sh)

if echo "$curl_lines" | grep -q "Authorization: Bearer"; then
    echo "  ✅ Authorization headers present in curl commands"
else
    echo "  ❌ Missing Authorization headers"
    exit 1
fi

if echo "$curl_lines" | grep -q '\\$'; then
    echo "  ✅ Proper line continuation in curl commands"
else
    echo "  ❌ Curl command structure may be incorrect"
    exit 1
fi

# Test 5: Verify JFrog CLI vs curl client usage
echo ""
echo "Test 5: Checking client type assignments"

jf_clients=$(grep -o '|jf|' ./cleanup.sh | wc -l | tr -d ' ')
curl_clients=$(grep -o '|curl|' ./cleanup.sh | wc -l | tr -d ' ')

echo "  JFrog CLI clients: $jf_clients"
echo "  Direct curl clients: $curl_clients"

if [[ "$jf_clients" -ge 2 ]] && [[ "$curl_clients" -ge 3 ]]; then
    echo "  ✅ Proper mix of JFrog CLI and curl clients"
else
    echo "  ❌ Client distribution may be incorrect"
fi

echo ""
echo "🎯 Validation Summary:"
echo "======================"
echo "✅ Script syntax is valid"
echo "✅ Removed problematic eval commands"  
echo "✅ Restored original working API endpoints"
echo "✅ Fixed curl command structure"
echo "✅ Proper authentication headers"
echo ""
echo "The cleanup script fix should resolve the HTTP 000 errors."
echo ""
echo "🧪 To test with your actual JFrog instance:"
echo "============================================"
echo "export JFROG_ADMIN_TOKEN='your-actual-token'"
echo "./cleanup.sh"
echo ""
echo "Expected behavior:"
echo "- No more 'HTTP 000' errors for repositories/users APIs"
echo "- Should successfully discover and delete resources"
echo "- Project deletion should work after resources are cleared"
