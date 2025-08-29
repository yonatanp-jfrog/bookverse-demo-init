#!/bin/bash

set -e

# Source environment and functions
source ../.secrets/env.sh
source ./.github/scripts/setup/common.sh

PROJECT_KEY="bookverse"
TEMP_DIR="/tmp/test_builds_$$"
mkdir -p "$TEMP_DIR"

echo "🧪 TESTING BUILD DELETION LOGIC"
echo "================================"
echo "Project: $PROJECT_KEY"
echo "Temp Dir: $TEMP_DIR"
echo ""

# Test the exact logic from cleanup_project_based.sh
echo "🔍 STEP 1: Discover project builds"
echo "-----------------------------------"

builds_file="$TEMP_DIR/project_builds.json"
filtered_builds="$TEMP_DIR/project_builds.txt"

echo "API Call: /artifactory/api/build?project=$PROJECT_KEY"
code=$(jfrog_api_call "GET" "/artifactory/api/build?project=$PROJECT_KEY" "$builds_file" "curl" "" "project builds")

echo "Response Code: $code"
echo "Response File Size: $(wc -c < "$builds_file" 2>/dev/null || echo 0) bytes"

if is_success "$code" && [[ -s "$builds_file" ]]; then
    echo "✅ API successful and returned data"
    echo ""
    echo "Raw Response:"
    cat "$builds_file"
    echo ""
    
    # Extract build names exactly like cleanup_project_based.sh does
    if jq -r '.builds[]?.uri' "$builds_file" 2>/dev/null | sed 's|^/||' > "$filtered_builds" 2>/dev/null && [[ -s "$filtered_builds" ]]; then
        count=$(wc -l < "$filtered_builds" 2>/dev/null || echo 0)
        echo "🏗️ Extracted $count builds:"
        cat "$filtered_builds"
        echo ""
        
        # Check if Commons-Build or evd are in the list
        if grep -q "Commons-Build\|evd" "$filtered_builds" 2>/dev/null; then
            echo "🚨 CRITICAL: Found non-project builds!"
            echo "This would explain why they're being deleted!"
            echo ""
            echo "Non-project builds found:"
            grep "Commons-Build\|evd" "$filtered_builds" || true
        else
            echo "✅ No non-project builds found in extraction"
        fi
    else
        echo "🔍 No builds extracted or extraction failed"
        count=0
    fi
else
    echo "❌ API failed or returned no data"
    count=0
fi

echo ""
echo "🗑️ STEP 2: Test deletion logic"
echo "-------------------------------"
echo "Discovered build count: $count"

if [[ "$count" -eq 0 ]]; then
    echo "✅ Would return early: 'No project builds to delete'"
    echo "✅ This is the expected behavior"
else
    echo "⚠️ Would proceed to delete $count builds:"
    if [[ -f "$filtered_builds" ]]; then
        while IFS= read -r build_name; do
            if [[ -n "$build_name" ]]; then
                echo "  → Would delete: $build_name"
            fi
        done < "$filtered_builds"
    fi
fi

echo ""
echo "🔍 STEP 3: Check for existing temp files"
echo "----------------------------------------"
echo "Looking for existing temp files that might interfere..."

# Check if there are any existing project_builds.txt files
existing_builds=$(find /tmp -name "project_builds.txt" -type f 2>/dev/null || true)
if [[ -n "$existing_builds" ]]; then
    echo "⚠️ Found existing project_builds.txt files:"
    echo "$existing_builds"
    echo ""
    echo "Content of existing files:"
    for file in $existing_builds; do
        echo "File: $file"
        if [[ -r "$file" ]]; then
            cat "$file" 2>/dev/null || echo "Cannot read file"
        else
            echo "Cannot access file"
        fi
        echo "---"
    done
else
    echo "✅ No existing project_builds.txt files found"
fi

echo ""
echo "🎯 SUMMARY"
echo "=========="
echo "Debug files saved in: $TEMP_DIR"
echo ""
if [[ "$count" -eq 0 ]]; then
    echo "✅ EXPECTED: Discovery found 0 builds, deletion would skip"
else
    echo "🚨 UNEXPECTED: Discovery found $count builds for deletion!"
fi

# Keep the debug files
echo ""
echo "Files created:"
ls -la "$TEMP_DIR/"
