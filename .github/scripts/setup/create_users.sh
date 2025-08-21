#!/usr/bin/env bash

set -e

# Source global configuration
source "$(dirname "$0")/config.sh"

# Validate environment variables
validate_environment

FAILED=false

echo "Creating users and assigning roles for BookVerse project..."

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

  # Assign appropriate role based on user type
  echo "🔐 Assigning $role role to $username..."
  
  # Determine the correct role name for JFrog
  case "$role" in
    "Developer")
      jfrog_role="Developer"
      ;;
    "Release Manager")
      jfrog_role="Release Manager"
      ;;
    "Project Manager")
      jfrog_role="Project Manager"
      ;;
    "AppTrust Admin")
      jfrog_role="AppTrust Admin"
      ;;
    "Inventory Manager")
      jfrog_role="Project Manager"
      ;;
    "AI/ML Manager")
      jfrog_role="Project Manager"
      ;;
    "Checkout Manager")
      jfrog_role="Project Manager"
      ;;
    "Pipeline User")
      jfrog_role="Developer"
      ;;
    *)
      jfrog_role="Developer"  # Default fallback
      ;;
  esac
  
  role_payload=$(jq -n --arg name "$username" --arg role "$jfrog_role" '{
    "name": $name,
    "roles": [$role]
  }')

  role_response_code=$(curl -s -o /dev/null -w "%{http_code}" \
    --header "Content-Type: application/json" \
    --header "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
    -X PUT \
    -d "$role_payload" \
    "${JFROG_URL}/access/api/v1/projects/${PROJECT_KEY}/users/$username")

  if [ "$role_response_code" -eq 200 ] || [ "$role_response_code" -eq 201 ]; then
    echo "✅ Project Admin role assigned to '$username' successfully (HTTP $role_response_code)"
  else
    echo "❌ Failed to assign Project Admin role to '$username' (HTTP $role_response_code)"
    FAILED=true
  fi
  echo ""
done

# Check if any operations failed
if [ "$FAILED" = true ]; then
  echo "❌ One or more critical operations failed. Exiting with error."
  exit 1
fi

echo "✅ User creation and role assignment process completed!"
echo "All users have been processed successfully."
echo ""
echo "📊 Summary of created users:"
echo "   - Alice Developer (alice.developer@bookverse.com) - Developer"
echo "   - Bob Release (bob.release@bookverse.com) - Release Manager"
echo "   - Charlie DevOps (charlie.devops@bookverse.com) - Project Manager"
echo "   - Diana Architect (diana.architect@bookverse.com) - AppTrust Admin"
echo "   - Edward Manager (edward.manager@bookverse.com) - AppTrust Admin"
echo "   - Frank Inventory (frank.inventory@bookverse.com) - Inventory Manager"
echo "   - Grace AI (grace.ai@bookverse.com) - AI/ML Manager"
echo "   - Henry Checkout (henry.checkout@bookverse.com) - Checkout Manager"
echo "   - Pipeline Inventory (pipeline.inventory@bookverse.com) - Pipeline User"
echo "   - Pipeline Recommendations (pipeline.recommendations@bookverse.com) - Pipeline User"
echo "   - Pipeline Checkout (pipeline.checkout@bookverse.com) - Pipeline User"
echo "   - Pipeline Platform (pipeline.platform@bookverse.com) - Pipeline User"
echo ""
echo "🔑 Default passwords:"
echo "   - Human users: BookVerse2024!"
echo "   - Pipeline users: Pipeline2024!"
echo "💡 Users can change their passwords after first login"
