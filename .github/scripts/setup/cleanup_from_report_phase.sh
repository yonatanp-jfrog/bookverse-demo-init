#!/usr/bin/env bash


set -e

source "$(dirname "$0")/config.sh"
source "$(dirname "$0")/common.sh"

PHASE="${1:-}"
CLEANUP_REPORT_FILE="${CLEANUP_REPORT_FILE:-.github/cleanup-report.json}"

if [[ -z "$PHASE" ]]; then
    echo "❌ Usage: $0 <phase>" >&2
    echo "Valid phases: users, domain_users, oidc, repositories, applications, stages, builds, project" >&2
    exit 1
fi

if [[ ! -f "$CLEANUP_REPORT_FILE" ]]; then
    echo "❌ Cleanup report not found: $CLEANUP_REPORT_FILE" >&2
    exit 1
fi

echo "🗑️ Starting cleanup phase: $PHASE"
echo "📋 Using report: $CLEANUP_REPORT_FILE"

cleanup_cicd_temp_user() {
    echo "🔧 Cleaning up temporary cicd platform admin user (workaround)..."
    
    local user_check_response=$(mktemp)
    local user_check_code=$(curl -s \
        --header "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
        --header "Accept: application/json" \
        -w "%{http_code}" -o "$user_check_response" \
        "${JFROG_URL}/access/api/v2/users/cicd")
    
    if [[ "$user_check_code" -eq 200 ]]; then
        echo "Found temporary cicd user - attempting removal..."
        
        local delete_response=$(mktemp)
        local delete_code=$(curl -s \
            --header "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
            -X DELETE \
            -w "%{http_code}" -o "$delete_response" \
            "${JFROG_URL}/access/api/v2/users/cicd")
        
        if [[ "$delete_code" -ge 200 && "$delete_code" -lt 300 ]]; then
            echo "✅ Temporary cicd user removed successfully"
        else
            echo "⚠️  Warning: Could not remove cicd user (HTTP $delete_code)"
            echo "Response: $(cat "$delete_response")"
            echo "💡 This user may need to be removed manually from the JFrog Platform UI"
        fi
        rm -f "$delete_response"
    else
        echo "ℹ️  Temporary cicd user not found (already removed or never created)"
    fi
    
    rm -f "$user_check_response"
    echo ""
}


case "$PHASE" in
    "users")
        echo "👥 Cleaning up project users..."
        jq -r '.plan.users[]?.name // empty' "$CLEANUP_REPORT_FILE" | while read -r username; do
            if [[ -n "$username" ]]; then
                echo "Removing user from project: $username"
            fi
        done
        ;;
        
    "domain_users")
        echo "👥 Cleaning up domain users..."
        jq -r '.plan.domain_users[]? // empty' "$CLEANUP_REPORT_FILE" | while read -r username; do
            if [[ -n "$username" ]]; then
                echo "Removing domain user: $username"
            fi
        done
        
        cleanup_cicd_temp_user
        ;;
        
    "oidc")
        echo "🔐 Cleaning up OIDC integrations..."
        jq -r '.plan.oidc[]? // empty' "$CLEANUP_REPORT_FILE" | while read -r integration_name; do
            if [[ -n "$integration_name" ]]; then
                echo "Removing OIDC integration: $integration_name"
                
                local delete_response=$(mktemp)
                local delete_code=$(curl -s \
                    --header "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
                    -X DELETE \
                    -w "%{http_code}" -o "$delete_response" \
                    "${JFROG_URL}/access/api/v1/oidc/${integration_name}")
                
                if [[ "$delete_code" -ge 200 && "$delete_code" -lt 300 ]]; then
                    echo "✅ OIDC integration '$integration_name' deleted successfully"
                else
                    echo "❌ Failed to delete OIDC integration '$integration_name' (HTTP $delete_code)"
                    echo "Response: $(cat "$delete_response")"
                fi
                rm -f "$delete_response"
            fi
        done
        ;;
        
    "repositories")
        echo "📦 Cleaning up repositories..."
        jq -r '.plan.repositories[]?.key // empty' "$CLEANUP_REPORT_FILE" | while read -r repo_key; do
            if [[ -n "$repo_key" ]]; then
                echo "Removing repository: $repo_key"
                
                local delete_response=$(mktemp)
                local delete_code=$(curl -s \
                    --header "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
                    -X DELETE \
                    -w "%{http_code}" -o "$delete_response" \
                    "${JFROG_URL}/artifactory/api/repositories/${repo_key}")
                
                if [[ "$delete_code" -ge 200 && "$delete_code" -lt 300 ]]; then
                    echo "✅ Repository '$repo_key' deleted successfully"
                else
                    echo "❌ Failed to delete repository '$repo_key' (HTTP $delete_code)"
                    echo "Response: $(cat "$delete_response")"
                fi
                rm -f "$delete_response"
            fi
        done
        ;;
        
    "applications")
        echo "🚀 Cleaning up applications..."
        jq -r '.plan.applications[]?.key // empty' "$CLEANUP_REPORT_FILE" | while read -r app_name; do
            if [[ -n "$app_name" ]]; then
                echo "Removing application: $app_name"
                
                local delete_response=$(mktemp)
                local delete_code=$(curl -s \
                    --header "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
                    -X DELETE \
                    -w "%{http_code}" -o "$delete_response" \
                    "${JFROG_URL}/apptrust/api/v1/applications/${app_name}")
                
                if [[ "$delete_code" -ge 200 && "$delete_code" -lt 300 ]]; then
                    echo "✅ Application '$app_name' deleted successfully"
                else
                    echo "❌ Failed to delete application '$app_name' (HTTP $delete_code)"
                    echo "Response: $(cat "$delete_response")"
                fi
                rm -f "$delete_response"
            fi
        done
        ;;
        
    "stages")
        echo "🏷️ Cleaning up lifecycle stages..."
        jq -r '.plan.stages[]?.name // empty' "$CLEANUP_REPORT_FILE" | while read -r stage_name; do
            if [[ -n "$stage_name" ]]; then
                echo "Removing stage: $stage_name"
                
                local delete_response=$(mktemp)
                local delete_code=$(curl -s \
                    --header "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
                    -X DELETE \
                    -w "%{http_code}" -o "$delete_response" \
                    "${JFROG_URL}/access/api/v2/lifecycle/${stage_name}")
                
                if [[ "$delete_code" -ge 200 && "$delete_code" -lt 300 ]]; then
                    echo "✅ Stage '$stage_name' deleted successfully"
                else
                    echo "❌ Failed to delete stage '$stage_name' (HTTP $delete_code)"
                    echo "Response: $(cat "$delete_response")"
                fi
                rm -f "$delete_response"
            fi
        done
        ;;
        
    "builds")
        echo "🔧 Cleaning up builds..."
        jq -r '.plan.builds[]?.name // empty' "$CLEANUP_REPORT_FILE" | while read -r build_name; do
            if [[ -n "$build_name" ]]; then
                echo "Removing build: $build_name"
                
                local delete_response=$(mktemp)
                local delete_code=$(curl -s \
                    --header "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
                    -X DELETE \
                    -w "%{http_code}" -o "$delete_response" \
                    "${JFROG_URL}/artifactory/api/build/${build_name}?deleteAll=1")
                
                if [[ "$delete_code" -ge 200 && "$delete_code" -lt 300 ]]; then
                    echo "✅ Build '$build_name' deleted successfully"
                else
                    echo "❌ Failed to delete build '$build_name' (HTTP $delete_code)"
                    echo "Response: $(cat "$delete_response")"
                fi
                rm -f "$delete_response"
            fi
        done
        ;;
        
    "project")
        echo "🎯 Cleaning up project..."
        local project_key=$(jq -r '.metadata.project_key // empty' "$CLEANUP_REPORT_FILE")
        
        if [[ -n "$project_key" ]]; then
            echo "Removing project: $project_key"
            
            local delete_response=$(mktemp)
            local delete_code=$(curl -s \
                --header "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
                -X DELETE \
                -w "%{http_code}" -o "$delete_response" \
                "${JFROG_URL}/access/api/v1/projects/${project_key}")
            
            if [[ "$delete_code" -ge 200 && "$delete_code" -lt 300 ]]; then
                echo "✅ Project '$project_key' deleted successfully"
            else
                echo "❌ Failed to delete project '$project_key' (HTTP $delete_code)"
                echo "Response: $(cat "$delete_response")"
            fi
            rm -f "$delete_response"
        else
            echo "⚠️  No project key found in cleanup report"
        fi
        ;;
        
    *)
        echo "❌ Unknown cleanup phase: $PHASE" >&2
        exit 1
        ;;
esac

echo "✅ Cleanup phase '$PHASE' completed"
