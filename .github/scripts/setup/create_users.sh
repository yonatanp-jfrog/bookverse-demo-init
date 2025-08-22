#!/usr/bin/env bash

set -e

# Source global configuration
source "$(dirname "$0")/config.sh"

# Validate environment variables
validate_environment

FAILED=false

echo "Creating users and assigning project roles for BookVerse project..."

# Generate 12 users for BookVerse company with specific roles
usernames=(
  '{"username": "alice.developer@bookverse.com", "email": "alice.developer@bookverse.com", "password": "BookVerse2024!", "role": "Developer"}'
  '{"username": "bob.release@bookverse.com", "email": "bob.release@bookverse.com", "password": "BookVerse2024!", "role": "Release Manager"}'
  '{"username": "charlie.devops@bookverse.com", "email": "charlie.devops@bookverse.com", "password": "BookVerse2024!", "role": "Project Manager"}'
  '{"username": "diana.architect@bookverse.com", "email": "diana.architect@bookverse.com", "password": "BookVerse2024!", "role": "AppTrust Admin"}'
  '{"username": "edward.manager@bookverse.com", "email": "edward.manager@bookverse.com", "password": "BookVerse2024!", "role": "AppTrust Admin"}'
  '{"username": "frank.inventory@bookverse.com", "email": "frank.inventory@bookverse.com", "password": "BookVerse2024!", "role": "Inventory Manager"}'
  '{"username": "grace.ai@bookverse.com", "email": "grace.ai@bookverse.com", "password": "BookVerse2024!", "role": "AI/ML Manager"}'
  '{"username": "henry.checkout@bookverse.com", "email": "henry.checkout@bookverse.com", "password": "BookVerse2024!", "role": "Checkout Manager"}'
  '{"username": "pipeline.inventory@bookverse.com", "email": "pipeline.inventory@bookverse.com", "password": "Pipeline2024!", "role": "Pipeline User"}'
  '{"username": "pipeline.recommendations@bookverse.com", "email": "pipeline.recommendations@bookverse.com", "password": "Pipeline2024!", "role": "Pipeline User"}'
  '{"username": "pipeline.checkout@bookverse.com", "email": "pipeline.checkout@bookverse.com", "password": "Pipeline2024!", "role": "Pipeline User"}'
  '{"username": "pipeline.platform@bookverse.com", "email": "pipeline.platform@bookverse.com", "password": "Pipeline2024!", "role": "Pipeline User"}'
)

echo "📋 Users to be created:"
for user in "${usernames[@]}"; do
  username=$(echo "$user" | jq -r '.username')
  role=$(echo "$user" | jq -r '.role')
  echo "   - $username ($role)"
done
echo ""

for user in "${usernames[@]}"; do
  username=$(echo "$user" | jq -r '.username')
  role=$(echo "$user" | jq -r '.role')
  echo "👤 Creating user: $username ($role)"
  
  # Create user (remove role from user payload)
  user_payload=$(echo "$user" | jq 'del(.role)')
  
  response_code=$(curl -s -o /dev/null -w "%{http_code}" \
    --header "Content-Type: application/json" \
    --header "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
    -X POST \
    -d "$user_payload" \
    "${JFROG_URL}/access/api/v2/users")

  if [ "$response_code" -eq 201 ]; then
    echo "✅ User '$username' created successfully (HTTP $response_code)"
  elif [ "$response_code" -eq 409 ]; then
    echo "⚠️  User '$username' already exists (HTTP $response_code)"
  else
    echo "❌ Failed to create user '$username' (HTTP $response_code)"
    FAILED=true
    continue  # Skip role assignment if user creation failed
  fi

  # Assign user to project with appropriate role
  echo "🔐 Assigning $username to project '${PROJECT_KEY}' with $role role..."
  
  # Determine the correct JFrog role name for project assignment
  case "$role" in
    "Developer")
      jfrog_role="Developer"
      ;;
    "Release Manager")
      jfrog_role="Release Manager"
      ;;
    "Project Manager")
      jfrog_role="Project Admin"
      ;;
    "AppTrust Admin")
      jfrog_role="Application Admin"
      ;;
    "Inventory Manager")
      jfrog_role="Project Admin"
      ;;
    "AI/ML Manager")
      jfrog_role="Project Admin"
      ;;
    "Checkout Manager")
      jfrog_role="Project Admin"
      ;;
    "Pipeline User")
      jfrog_role="Developer"
      ;;
    *)
      jfrog_role="Developer"  # Default fallback
      ;;
  esac
  
  # Create project user assignment payload
  # Using the correct API endpoint: PUT /access/api/v1/projects/{projectKey}/users/{username}
  project_user_payload=$(jq -n --arg username "$username" --arg role "$jfrog_role" '{
    "name": $username,
    "roles": [$role]
  }')

  echo "   📤 Assigning role '$jfrog_role' to user '$username' in project '${PROJECT_KEY}'..."
  echo "   🔗 API: PUT ${JFROG_URL}/access/api/v1/projects/${PROJECT_KEY}/users/$username"
  echo "   📋 Payload: $project_user_payload"

  project_user_response_code=$(curl -s -o /dev/null -w "%{http_code}" \
    --header "Content-Type: application/json" \
    --header "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
    -X PUT \
    -d "$project_user_payload" \
    "${JFROG_URL}/access/api/v1/projects/${PROJECT_KEY}/users/$username")

  if [ "$project_user_response_code" -eq 200 ] || [ "$project_user_response_code" -eq 201 ]; then
    echo "✅ User '$username' successfully assigned to project '${PROJECT_KEY}' with role '$jfrog_role' (HTTP $project_user_response_code)"
    echo "   Status: SUCCESS - User now has access to project resources"
    echo "   Role: $jfrog_role"
    echo "   Project: ${PROJECT_KEY}"
  elif [ "$project_user_response_code" -eq 409 ]; then
    echo "⚠️  User '$username' already has role '$jfrog_role' in project '${PROJECT_KEY}' (HTTP $project_user_response_code)"
    echo "   Status: SKIPPED - User already assigned to project"
  elif [ "$project_user_response_code" -eq 404 ]; then
    echo "❌ Project '${PROJECT_KEY}' not found for user assignment (HTTP $project_user_response_code)"
    echo "   Status: ERROR - Cannot assign user to non-existent project"
    FAILED=true
  else
    echo "❌ Failed to assign user '$username' to project '${PROJECT_KEY}' (HTTP $project_user_response_code)"
    echo "   Status: ERROR - User assignment failed"
    FAILED=true
  fi
  echo ""
done

# Check if any operations failed
if [ "$FAILED" = true ]; then
  echo "❌ One or more critical operations failed. Exiting with error."
  exit 1
fi

echo "✅ User creation and project role assignment process completed!"
echo "All users have been processed successfully."
echo ""
echo "📊 Summary of created users and project assignments:"
echo "   - Alice Developer (alice.developer@bookverse.com) - Developer role in ${PROJECT_KEY} project"
echo "   - Bob Release (bob.release@bookverse.com) - Release Manager role in ${PROJECT_KEY} project"
echo "   - Charlie DevOps (charlie.devops@bookverse.com) - Project Admin role in ${PROJECT_KEY} project"
echo "   - Diana Architect (diana.architect@bookverse.com) - Application Admin role in ${PROJECT_KEY} project"
echo "   - Edward Manager (edward.manager@bookverse.com) - Application Admin role in ${PROJECT_KEY} project"
echo "   - Frank Inventory (frank.inventory@bookverse.com) - Project Admin role in ${PROJECT_KEY} project"
echo "   - Grace AI (grace.ai@bookverse.com) - Project Admin role in ${PROJECT_KEY} project"
echo "   - Henry Checkout (henry.checkout@bookverse.com) - Project Admin role in ${PROJECT_KEY} project"
echo "   - Pipeline Inventory (pipeline.inventory@bookverse.com) - Developer role in ${PROJECT_KEY} project"
echo "   - Pipeline Recommendations (pipeline.recommendations@bookverse.com) - Developer role in ${PROJECT_KEY} project"
echo "   - Pipeline Checkout (pipeline.checkout@bookverse.com) - Developer role in ${PROJECT_KEY} project"
echo "   - Pipeline Platform (pipeline.platform@bookverse.com) - Developer role in ${PROJECT_KEY} project"
echo ""
echo "🔑 Default passwords:"
echo "   - Human users: BookVerse2024!"
echo "   - Pipeline users: Pipeline2024!"
echo "💡 Users can change their passwords after first login"
echo ""
echo "🎯 Project Access:"
echo "   - All users are now assigned to the '${PROJECT_KEY}' project"
echo "   - Roles determine access levels to project resources"
echo "   - Users can access repositories, stages, and applications based on their roles"
