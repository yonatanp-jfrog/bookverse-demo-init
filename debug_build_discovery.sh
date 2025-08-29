#!/bin/bash

# DEBUG: Investigate what builds are being discovered and why non-project builds are being deleted

set -e

# Source environment
source ./.secrets/env.sh 2>/dev/null || {
    echo "❌ Cannot source ./.secrets/env.sh"
    exit 1
}

# Source common functions
source ./.github/scripts/setup/common.sh

PROJECT_KEY="${PROJECT_KEY:-bookverse}"
TEMP_DEBUG="/tmp/debug_builds_$$"
mkdir -p "$TEMP_DEBUG"

echo "🔍 BUILD DISCOVERY DEBUG INVESTIGATION"
echo "======================================"
echo "Project: $PROJECT_KEY"
echo "JFrog URL: $JFROG_URL" 
echo "Debug Dir: $TEMP_DEBUG"
echo ""

# 1. Test the exact API call that cleanup_project_based.sh uses
echo "🎯 TEST 1: Project-filtered build discovery"
echo "API: /artifactory/api/build?project=$PROJECT_KEY"
echo ""

project_builds_file="$TEMP_DEBUG/project_builds.json"
code=$(jfrog_api_call "GET" "/artifactory/api/build?project=$PROJECT_KEY" "$project_builds_file" "curl" "" "project builds")

echo "Response Code: $code"
if [[ -s "$project_builds_file" ]]; then
    echo "Response Size: $(wc -c < "$project_builds_file") bytes"
    echo ""
    echo "🔍 Raw API Response:"
    echo "-------------------"
    jq '.' "$project_builds_file" 2>/dev/null || cat "$project_builds_file"
    echo ""
    
    echo "🏗️ Extracted Build Names:"
    echo "-------------------------"
    if jq -r '.builds[]?.uri' "$project_builds_file" 2>/dev/null | sed 's|^/||' > "$TEMP_DEBUG/extracted_builds.txt"; then
        if [[ -s "$TEMP_DEBUG/extracted_builds.txt" ]]; then
            cat "$TEMP_DEBUG/extracted_builds.txt"
            echo ""
            echo "Count: $(wc -l < "$TEMP_DEBUG/extracted_builds.txt") builds"
        else
            echo "(No builds extracted)"
        fi
    else
        echo "❌ Failed to extract build names"
    fi
else
    echo "❌ No response data or API failed"
    if [[ -f "$project_builds_file" ]]; then
        echo "Error response:"
        cat "$project_builds_file"
    fi
fi

echo ""
echo "================================================"

# 2. Test unfiltered build discovery (to see what would happen without project filter)
echo "🎯 TEST 2: Unfiltered build discovery (for comparison)"
echo "API: /artifactory/api/build"
echo ""

all_builds_file="$TEMP_DEBUG/all_builds.json"
code=$(jfrog_api_call "GET" "/artifactory/api/build" "$all_builds_file" "curl" "" "all builds")

echo "Response Code: $code"
if [[ -s "$all_builds_file" ]]; then
    echo "Response Size: $(wc -c < "$all_builds_file") bytes"
    echo ""
    
    echo "🏗️ All Build Names (first 20):"
    echo "------------------------------"
    if jq -r '.builds[]?.uri' "$all_builds_file" 2>/dev/null | sed 's|^/||' | head -20 > "$TEMP_DEBUG/all_builds_sample.txt"; then
        cat "$TEMP_DEBUG/all_builds_sample.txt"
        echo ""
        total_count=$(jq -r '.builds[]?.uri' "$all_builds_file" 2>/dev/null | wc -l)
        echo "Total Count: $total_count builds"
        
        # Check if Commons-Build and evd are in the unfiltered list
        echo ""
        echo "🔍 Looking for problematic builds:"
        echo "  Commons-Build: $(jq -r '.builds[]?.uri' "$all_builds_file" 2>/dev/null | grep -c "Commons-Build" || echo "0") occurrences"
        echo "  evd: $(jq -r '.builds[]?.uri' "$all_builds_file" 2>/dev/null | grep -c "evd" || echo "0") occurrences"
    else
        echo "❌ Failed to extract build names"
    fi
else
    echo "❌ No response data or API failed"
fi

echo ""
echo "================================================"

# 3. Compare the two lists to see if project filtering is working
echo "🎯 TEST 3: Compare filtered vs unfiltered"
echo ""

if [[ -f "$TEMP_DEBUG/extracted_builds.txt" ]] && [[ -f "$TEMP_DEBUG/all_builds_sample.txt" ]]; then
    project_count=$(wc -l < "$TEMP_DEBUG/extracted_builds.txt" 2>/dev/null || echo 0)
    
    if [[ "$project_count" -gt 0 ]]; then
        echo "❌ CRITICAL FINDING:"
        echo "Project-filtered API returned builds, but user reported non-project builds being deleted!"
        echo ""
        echo "This suggests either:"
        echo "1. The API filter is not working correctly"
        echo "2. A different script/path is being used"
        echo "3. The builds actually belong to the project but have unexpected names"
        echo ""
        
        echo "🔍 Project builds that will be deleted:"
        cat "$TEMP_DEBUG/extracted_builds.txt"
    else
        echo "✅ Project-filtered API returned 0 builds (as expected if properly filtered)"
    fi
else
    echo "⚠️ Could not compare - missing data files"
fi

echo ""
echo "🎯 DEBUG SUMMARY:"
echo "=================="
echo "Debug files saved in: $TEMP_DEBUG"
echo ""
echo "CRITICAL QUESTION: Are the 'Commons-Build' and 'evd' builds"
echo "actually being returned by the project-filtered API?"
echo ""
echo "If YES: The API filter is broken (JFrog bug)"
echo "If NO: The cleanup script has a different bug"

# Keep the debug files for inspection
echo ""
echo "Debug files:"
ls -la "$TEMP_DEBUG/"
