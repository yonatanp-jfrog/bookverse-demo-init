#!/usr/bin/env bash

set -e

# Source global configuration
source "$(dirname "$0")/config.sh"

# =============================================================================
# CONFIGURATION - Easy to modify stage names and order
# =============================================================================
# Local stages to create (PROD is always last)
STAGES=("${LOCAL_STAGES[@]}")
# =============================================================================

FAILED=false

# Validate environment variables
validate_environment

echo "Creating local stages in project: ${PROJECT_KEY}"
echo "JFrog URL: ${JFROG_URL}"
echo "Local stages to create: ${STAGES[*]}"
echo "Note: ${PROD_STAGE} stage is always present and always last"
echo ""


echo "Step 1: Creating local stages..."

for STAGE_NAME in "${STAGES[@]}"; do
  echo "Creating stage: $STAGE_NAME"
  
  stage_payload=$(jq -n \
    --arg name "$STAGE_NAME" \
    --arg project_key "${PROJECT_KEY}" \
    '{
      "name": $name,
      "scope": "project",
      "project_key": $project_key,
      "category": "promote"
    }')

  temp_response=$(mktemp)
  response_code=$(curl -s -w "%{http_code}" -o "$temp_response" \
    --header "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
    --header "Content-Type: application/json" \
    -X POST \
    -d "$stage_payload" \
    "${JFROG_URL}/access/api/v2/stages/")

  response_body=$(cat "$temp_response")
  rm -f "$temp_response"

  if [ "$response_code" -eq 201 ]; then
    echo "✅ Stage '$STAGE_NAME' created successfully (HTTP $response_code)"
  elif [ "$response_code" -eq 409 ]; then
    echo "⚠️  Stage '$STAGE_NAME' already exists (HTTP $response_code)"
  elif [ "$response_code" -eq 400 ] && echo "$response_body" | grep -q "already exists"; then
    echo "⚠️  Stage '$STAGE_NAME' already exists (HTTP $response_code)"
  else
    echo "❌ Failed to create stage '$STAGE_NAME' (HTTP $response_code)"
    echo "   Response body: $response_body"
    FAILED=true
  fi
  echo ""
done


echo "Step 2: Updating lifecycle with promote stages (${PROD_STAGE} is always last)..."

# Convert STAGES array to JSON array format for the payload, then add PROD at the end
stages_json=$(printf '%s\n' "${STAGES[@]}" | jq -R . | jq -s .)
stages_with_prod=$(echo "$stages_json" | jq --arg prod "${PROD_STAGE}" '. + [$prod]')

lifecycle_payload=$(jq -n \
  --argjson stages "$stages_with_prod" \
  '{
    "promote_stages": $stages
  }')

temp_response=$(mktemp)
response_code=$(curl -s -w "%{http_code}" -o "$temp_response" \
  --header "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
  --header "Content-Type: application/json" \
  -X PATCH \
  -d "$lifecycle_payload" \
  "${JFROG_URL}/access/api/v2/lifecycle/?project_key=${PROJECT_KEY}")

response_body=$(cat "$temp_response")
rm -f "$temp_response"

if [ "$response_code" -eq 200 ] || [ "$response_code" -eq 204 ]; then
  echo "✅ Lifecycle updated successfully with promote stages (HTTP $response_code)"
  echo "   Promote stages: $(IFS=" → "; echo "${STAGES[*]}") → ${PROD_STAGE}"
elif [ "$response_code" -eq 404 ]; then
  echo "❌ Project '${PROJECT_KEY}' not found for lifecycle update (HTTP $response_code)"
  FAILED=true
else
  echo "❌ Failed to update lifecycle (HTTP $response_code)"
  echo "   Response body: $response_body"
  FAILED=true
fi
echo ""


if [ "$FAILED" = true ]; then
  echo "❌ One or more critical operations failed. Exiting with error."
  exit 1
fi

echo "✅ Local stages and lifecycle configuration completed successfully!"
echo "Summary of completed tasks:"
for STAGE_NAME in "${STAGES[@]}"; do
  echo "   - $STAGE_NAME stage created in project '${PROJECT_KEY}'"
done
echo "   - ${PROD_STAGE} stage is always present (not created by this script)"
echo "   - Lifecycle updated with promote stages: $(IFS=" → "; echo "${STAGES[*]}") → ${PROD_STAGE}"
echo ""
echo "Project is now ready with local stages and lifecycle configuration!"