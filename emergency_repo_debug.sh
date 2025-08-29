#!/bin/bash

set -e

# EMERGENCY: Debug why ALL repositories are being deleted

# Source environment and functions
source ../.secrets/env.sh
source ./.github/scripts/setup/common.sh

PROJECT_KEY="bookverse"
TEMP_DIR="/tmp/emergency_debug_$$"
mkdir -p "$TEMP_DIR"

echo "🚨 EMERGENCY REPOSITORY DELETION DEBUG"
echo "======================================"
echo "Project: $PROJECT_KEY"
echo "Temp Dir: $TEMP_DIR"
echo ""

# Test the EXACT logic from discover_project_repositories()
repos_file="$TEMP_DIR/project_repositories.json"
filtered_repos="$TEMP_DIR/project_repositories.txt"

echo "🔍 STEP 1: Get ALL repositories"
echo "------------------------------"
code=$(jfrog_api_call "GET" "/artifactory/api/repositories" "$repos_file" "curl" "" "all repositories")

echo "Response Code: $code"
total_repos=$(jq length "$repos_file" 2>/dev/null || echo 0)
echo "Total repositories in system: $total_repos"

echo ""
echo "Sample repositories (first 10):"
jq -r '.[].key' "$repos_file" 2>/dev/null | head -10

echo ""
echo "🔍 STEP 2: Test filtering logic"
echo "------------------------------"

# Test the exact filtering condition from line 245
echo "Testing: jq '[.[] | select(.key | contains(\"$PROJECT_KEY\"))]'"
if jq --arg project "$PROJECT_KEY" '[.[] | select(.key | contains($project))]' "$repos_file" > "${repos_file}.filtered" 2>/dev/null && [[ -s "${repos_file}.filtered" ]]; then
    echo "✅ PRIMARY FILTER PASSED!"
    filtered_count=$(jq length "${repos_file}.filtered" 2>/dev/null || echo 0)
    echo "Filtered count: $filtered_count"
    
    if [[ "$filtered_count" -gt 0 ]]; then
        echo "Repositories that passed filter:"
        jq -r '.[].key' "${repos_file}.filtered" 2>/dev/null
        echo ""
        
        # Check if any of these contain bookverse
        echo "Checking if filtered repos actually contain 'bookverse':"
        jq -r '.[].key' "${repos_file}.filtered" 2>/dev/null | while read -r repo; do
            if [[ "$repo" == *"bookverse"* ]]; then
                echo "  ✅ $repo (contains bookverse)"
            else
                echo "  ❌ $repo (DOES NOT contain bookverse!)"
            fi
        done
    fi
    
    # Move filtered file like the original script does
    mv "${repos_file}.filtered" "$repos_file"
    
else
    echo "❌ PRIMARY FILTER FAILED"
    
    # Test fallback: prefix match
    echo "Testing: jq '[.[] | select(.key | startswith(\"$PROJECT_KEY\"))]'"
    if jq --arg project "$PROJECT_KEY" '[.[] | select(.key | startswith($project))]' "$repos_file" > "${repos_file}.filtered" 2>/dev/null && [[ -s "${repos_file}.filtered" ]]; then
        echo "✅ PREFIX FILTER PASSED!"
        mv "${repos_file}.filtered" "$repos_file"
    else
        echo "❌ PREFIX FILTER FAILED"
        
        # Test final fallback: projectKey
        echo "Testing: jq '[.[] | select(.projectKey == \"$PROJECT_KEY\")]'"
        if jq --arg project "$PROJECT_KEY" '[.[] | select(.projectKey == $project)]' "$repos_file" > "${repos_file}.filtered" 2>/dev/null && [[ -s "${repos_file}.filtered" ]]; then
            echo "✅ PROJECTKEY FILTER PASSED!"
            mv "${repos_file}.filtered" "$repos_file"
        else
            echo "❌ ALL FILTERS FAILED"
            echo "Writing empty array to file..."
            echo "[]" > "$repos_file"
        fi
    fi
fi

echo ""
echo "🔍 STEP 3: Final extraction (line 274 logic)"
echo "--------------------------------------------"

# Test the final condition and extraction (lines 272-274)
if is_success "$code" && [[ -s "$repos_file" ]]; then
    echo "✅ Final condition passed: is_success($code) && file_has_content"
    echo "File size: $(wc -c < "$repos_file") bytes"
    echo "File content:"
    cat "$repos_file"
    echo ""
    
    echo "Extracting repository keys..."
    jq -r '.[] | .key' "$repos_file" > "$filtered_repos"
    
    final_count=$(wc -l < "$filtered_repos" 2>/dev/null || echo 0)
    echo "Final repositories to delete: $final_count"
    
    if [[ "$final_count" -gt 0 ]]; then
        echo ""
        echo "🚨 REPOSITORIES THAT WOULD BE DELETED:"
        echo "====================================="
        cat "$filtered_repos"
        echo ""
        
        # Check if any of these are non-bookverse repos (like user reported)
        echo "🚨 CHECKING FOR NON-BOOKVERSE REPOS:"
        while IFS= read -r repo; do
            if [[ "$repo" == *"bookverse"* ]]; then
                echo "  ✅ $repo (safe - contains bookverse)"
            else
                echo "  ❌ $repo (DANGEROUS - no bookverse!)"
            fi
        done < "$filtered_repos"
    fi
else
    echo "❌ Final condition failed"
fi

echo ""
echo "🎯 EMERGENCY ANALYSIS COMPLETE"
echo "============================="
echo "Debug files saved in: $TEMP_DIR"
