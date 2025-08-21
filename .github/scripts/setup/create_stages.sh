#!/usr/bin/env bash

set -e

FAILED=false
if [[ -z "${AUTH_TOKEN}" ]]; then
  echo "❌ Error: AUTH_TOKEN is not set. Please export AUTH_TOKEN and try again."
  exit 1
fi

if [[ -z "${JF_URL}" ]]; then
  echo "❌ Error: JF_URL is not set. Please export JF_URL and try again."
  exit 1
fi


PROJECT_KEY="gpizza"
STAGES=("QA")

echo "Creating QA stage and updating lifecycle for project: $PROJECT_KEY"
echo "JFrog URL: ${JF_URL}"
echo ""


echo "Step 1: Creating stages..."

for STAGE_NAME in "${STAGES[@]}"; do
  echo "Creating stage: $STAGE_NAME"
  
  stage_payload=$(jq -n \
    --arg name "$STAGE_NAME" \
    --arg project_key "$PROJECT_KEY" \
    '{
      "name": $name
    }')

  temp_response=$(mktemp)
  response_code=$(curl -s -w "%{http_code}" -o "$temp_response" \
    --header "Authorization: Bearer ${AUTH_TOKEN}" \
    --header "Content-Type: application/json" \
    -X POST \
    -d "$stage_payload" \
    "${JF_URL}/access/api/v2/stages/")

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


echo "Step 2: Updating lifecycle with promote stages..."

lifecycle_payload=$(jq -n '{
  "promote_stages": [
    "DEV",
    "QA"
  ]
}')

temp_response=$(mktemp)
response_code=$(curl -s -w "%{http_code}" -o "$temp_response" \
  --header "Authorization: Bearer ${AUTH_TOKEN}" \
  --header "Content-Type: application/json" \
  -X PATCH \
  -d "$lifecycle_payload" \
  "${JF_URL}/access/api/v2/lifecycle/?project_key=${PROJECT_KEY}")

response_body=$(cat "$temp_response")
rm -f "$temp_response"

if [ "$response_code" -eq 200 ] || [ "$response_code" -eq 204 ]; then
  echo "✅ Lifecycle updated successfully with promote stages (HTTP $response_code)"
  echo "   Promote stages: DEV → QA"
elif [ "$response_code" -eq 404 ]; then
  echo "❌ Project '$PROJECT_KEY' not found for lifecycle update (HTTP $response_code)"
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

echo "✅ QA stage and lifecycle configuration completed successfully!"
echo "Summary of completed tasks:"
echo "   - QA stage created in project '$PROJECT_KEY'"
echo "   - Lifecycle updated with promote stages: DEV → QA"
echo ""
echo "Project is now ready with QA stage and lifecycle configuration!"