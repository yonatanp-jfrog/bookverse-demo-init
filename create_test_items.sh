#!/bin/bash

# Create test items for comprehensive project filtering validation
# DO NOT RUN THIS SCRIPT MANUALLY - It's used by the testing process

set -e

# Source common functions
source "$(dirname "$0")/.github/scripts/setup/common.sh"

# Initialize script
init_script "create_test_items" "Creating Test Items for Project Filtering Validation"

echo "🧪 CREATING TEST ITEMS FOR PROJECT FILTERING VALIDATION"
echo "======================================================="
echo ""

# Generate random suffixes to ensure unique names
RANDOM_SUFFIX=$(date +%s | tail -c 4)
TEST_PREFIX="test-random-${RANDOM_SUFFIX}"

echo "🎯 SCENARIO 1: Random names IN bookverse project (should be deleted)"
echo "=================================================================="

# Test 1.1: Create repository with random name in bookverse project
echo "📦 Creating test repository: ${TEST_PREFIX}-repo"
TEST_REPO_PAYLOAD='{
    "key": "'${TEST_PREFIX}'-repo",
    "rclass": "local",
    "packageType": "generic",
    "description": "TEST REPO - Random name in bookverse project - SHOULD BE DELETED",
    "projectKey": "bookverse"
}'

echo "$TEST_REPO_PAYLOAD" > /tmp/test_repo_payload.json
code=$(jfrog_api_call "PUT" "/artifactory/api/repositories/${TEST_PREFIX}-repo" "/tmp/test_repo_payload.json" "curl" "" "create test repository in bookverse project")

if is_success "$code"; then
    echo "✅ Created test repository: ${TEST_PREFIX}-repo (in bookverse project)"
else
    echo "❌ Failed to create test repository"
fi

# Test 1.2: Create application with random name in bookverse project
echo ""
echo "🚀 Creating test application: ${TEST_PREFIX}-app"
TEST_APP_PAYLOAD='{
    "application_name": "'${TEST_PREFIX}'-app",
    "description": "TEST APP - Random name in bookverse project - SHOULD BE DELETED"
}'

echo "$TEST_APP_PAYLOAD" > /tmp/test_app_payload.json
code=$(jfrog_api_call "POST" "/lifecycle/api/v2/applications?projectKey=bookverse" "/tmp/test_app_payload.json" "curl" "" "create test application in bookverse project")

if is_success "$code"; then
    echo "✅ Created test application: ${TEST_PREFIX}-app (in bookverse project)"
else
    echo "❌ Failed to create test application"
fi

# Test 1.3: Create user with random name in bookverse project  
echo ""
echo "👤 Creating test user: ${TEST_PREFIX}-user"
TEST_USER_PAYLOAD='{
    "username": "'${TEST_PREFIX}'-user",
    "email": "'${TEST_PREFIX}'-user@testdomain.com",
    "password": "TempPassword123!",
    "admin": false,
    "profileUpdatable": true,
    "disableUIAccess": false,
    "groups": []
}'

echo "$TEST_USER_PAYLOAD" > /tmp/test_user_payload.json
code=$(jfrog_api_call "PUT" "/access/api/v2/users/${TEST_PREFIX}-user" "/tmp/test_user_payload.json" "curl" "" "create test user")

if is_success "$code"; then
    echo "✅ Created test user: ${TEST_PREFIX}-user"
    
    # Add user to bookverse project
    echo "📋 Adding user to bookverse project..."
    PROJECT_ASSIGNMENT_PAYLOAD='{
        "name": "'${TEST_PREFIX}'-user",
        "roles": ["Developer"]
    }'
    
    echo "$PROJECT_ASSIGNMENT_PAYLOAD" > /tmp/test_project_assignment.json
    code=$(jfrog_api_call "PUT" "/access/api/v2/projects/bookverse/users/${TEST_PREFIX}-user" "/tmp/test_project_assignment.json" "curl" "" "assign user to bookverse project")
        
    if is_success "$code"; then
        echo "✅ Assigned test user to bookverse project"
    else
        echo "❌ Failed to assign user to bookverse project"
    fi
else
    echo "❌ Failed to create test user"
fi

echo ""
echo "🎯 SCENARIO 2: 'bookverse' names OUTSIDE bookverse project (should NOT be deleted)"
echo "=============================================================================="

# Test 2.1: Create repository with bookverse name in global (no project)
echo "📦 Creating test repository: bookverse-global-test-${RANDOM_SUFFIX}"
GLOBAL_REPO_PAYLOAD='{
    "key": "bookverse-global-test-'${RANDOM_SUFFIX}'",
    "rclass": "local", 
    "packageType": "generic",
    "description": "TEST REPO - bookverse name OUTSIDE bookverse project - should NOT be deleted"
}'

echo "$GLOBAL_REPO_PAYLOAD" > /tmp/global_repo_payload.json
code=$(jfrog_api_call "PUT" "/artifactory/api/repositories/bookverse-global-test-${RANDOM_SUFFIX}" "/tmp/global_repo_payload.json" "curl" "" "create global test repository with bookverse name")

if is_success "$code"; then
    echo "✅ Created global test repository: bookverse-global-test-${RANDOM_SUFFIX}"
else
    echo "❌ Failed to create global test repository"
fi

# Test 2.2: Create user with bookverse name (not in bookverse project)
echo ""
echo "👤 Creating test user: bookverse-external-user-${RANDOM_SUFFIX}"
EXTERNAL_USER_PAYLOAD='{
    "username": "bookverse-external-user-'${RANDOM_SUFFIX}'",
    "email": "bookverse-external-user-'${RANDOM_SUFFIX}'@testdomain.com", 
    "password": "TempPassword123!",
    "admin": false,
    "profileUpdatable": true,
    "disableUIAccess": false,
    "groups": []
}'

echo "$EXTERNAL_USER_PAYLOAD" > /tmp/external_user_payload.json
code=$(jfrog_api_call "PUT" "/access/api/v2/users/bookverse-external-user-${RANDOM_SUFFIX}" "/tmp/external_user_payload.json" "curl" "" "create external test user with bookverse name")

if is_success "$code"; then
    echo "✅ Created external test user: bookverse-external-user-${RANDOM_SUFFIX}"
else
    echo "❌ Failed to create external test user"
fi

echo ""
echo "📋 TEST ITEMS CREATION SUMMARY"
echo "=============================="
echo "✅ SCENARIO 1 (should be deleted by cleanup):"
echo "   - Repository: ${TEST_PREFIX}-repo (in bookverse project)"
echo "   - Application: ${TEST_PREFIX}-app (in bookverse project)"  
echo "   - User: ${TEST_PREFIX}-user (in bookverse project)"
echo ""
echo "✅ SCENARIO 2 (should NOT be deleted by cleanup):"
echo "   - Repository: bookverse-global-test-${RANDOM_SUFFIX} (global)"
echo "   - User: bookverse-external-user-${RANDOM_SUFFIX} (not in bookverse project)"
echo ""
echo "💾 SAVING TEST ITEM NAMES FOR CLEANUP..."

# Save test item names for later cleanup
cat > test_items_created.txt << EOF
# Test items created for project filtering validation
# SCENARIO 1 (in bookverse project - should be deleted):
REPO_IN_PROJECT=${TEST_PREFIX}-repo
APP_IN_PROJECT=${TEST_PREFIX}-app  
USER_IN_PROJECT=${TEST_PREFIX}-user

# SCENARIO 2 (outside bookverse project - should NOT be deleted):
REPO_GLOBAL=bookverse-global-test-${RANDOM_SUFFIX}
USER_EXTERNAL=bookverse-external-user-${RANDOM_SUFFIX}

# Random suffix used: ${RANDOM_SUFFIX}
EOF

echo "✅ Test item names saved to test_items_created.txt"
echo "🎯 Ready for cleanup script testing!"
