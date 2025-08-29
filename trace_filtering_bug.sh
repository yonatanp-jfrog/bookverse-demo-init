#!/bin/bash

# RCA: Trace the exact filtering logic failure that caused ALL repos to be deleted

set -e

echo "🔍 ROOT CAUSE ANALYSIS: Repository Filtering Failure"
echo "===================================================="
echo ""

# Create test data that simulates what the API would return
TEMP_DEBUG="/tmp/rca_debug_$$"
mkdir -p "$TEMP_DEBUG"

echo "📋 SIMULATING REPOSITORY API RESPONSE"
echo "======================================"

# Create a realistic repository list similar to what user reported
cat > "$TEMP_DEBUG/all_repos.json" << 'EOF'
[
  {"key": "bookverse-dev-docker", "type": "LOCAL", "description": "BookVerse Dev Docker"},
  {"key": "bookverse-prod-maven", "type": "LOCAL", "description": "BookVerse Prod Maven"},
  {"key": "carmit-prj-1-carmit-python-local", "type": "LOCAL", "description": "Carmit Python Local"},
  {"key": "carmit-prj-1-carmit-python-qa", "type": "LOCAL", "description": "Carmit Python QA"},
  {"key": "carmit-prj-1-npm-local", "type": "LOCAL", "description": "Carmit NPM Local"},
  {"key": "catalina-dev-docker-local", "type": "LOCAL", "description": "Catalina Dev Docker"},
  {"key": "catalina-prod-maven-local", "type": "LOCAL", "description": "Catalina Prod Maven"},
  {"key": "catalina-qa-generic-local", "type": "LOCAL", "description": "Catalina QA Generic"},
  {"key": "some-other-project-repo", "type": "LOCAL", "description": "Other Project"}
]
EOF

PROJECT_KEY="bookverse"
repos_file="$TEMP_DEBUG/project_repositories.json"
cp "$TEMP_DEBUG/all_repos.json" "$repos_file"

echo "Total repositories: $(jq length "$repos_file")"
echo "Sample repositories:"
jq -r '.[] | .key' "$repos_file" | head -5

echo ""
echo "🧪 TESTING FILTERING LOGIC (Line 245)"
echo "====================================="

echo "Filter: jq '[.[] | select(.key | contains(\"$PROJECT_KEY\"))]'"

# Test the exact filter from line 245
if jq --arg project "$PROJECT_KEY" '[.[] | select(.key | contains($project))]' "$repos_file" > "${repos_file}.filtered" 2>/dev/null && [[ -s "${repos_file}.filtered" ]]; then
    echo "✅ PRIMARY FILTER PASSED"
    
    filtered_count=$(jq length "${repos_file}.filtered")
    echo "Filtered count: $filtered_count"
    
    echo ""
    echo "🔍 REPOSITORIES THAT PASSED FILTER:"
    echo "-----------------------------------"
    jq -r '.[] | .key' "${repos_file}.filtered"
    
    echo ""
    echo "🚨 CRITICAL ANALYSIS:"
    echo "====================="
    
    # Check if any non-bookverse repos passed the filter
    non_bookverse_found=false
    while IFS= read -r repo; do
        if [[ "$repo" == *"bookverse"* ]]; then
            echo "  ✅ $repo (correct - contains bookverse)"
        else
            echo "  ❌ $repo (WRONG - no bookverse!)"
            non_bookverse_found=true
        fi
    done < <(jq -r '.[] | .key' "${repos_file}.filtered")
    
    if [[ "$non_bookverse_found" == "true" ]]; then
        echo ""
        echo "🚨 BUG CONFIRMED: Filter passed non-bookverse repositories!"
        echo "This explains why carmit-*, catalina-* were being deleted!"
    else
        echo ""
        echo "✅ Filter working correctly - only bookverse repos passed"
    fi
    
    # Simulate the move operation (line 246)
    mv "${repos_file}.filtered" "$repos_file"
    echo ""
    echo "📁 File moved: ${repos_file}.filtered → $repos_file"
    
else
    echo "❌ PRIMARY FILTER FAILED"
    
    # Test fallback: prefix match (line 256)
    echo ""
    echo "🧪 TESTING FALLBACK: PREFIX MATCH"
    echo "================================="
    echo "Filter: jq '[.[] | select(.key | startswith(\"$PROJECT_KEY\"))]'"
    
    cp "$TEMP_DEBUG/all_repos.json" "$repos_file"  # Reset to original
    
    if jq --arg project "$PROJECT_KEY" '[.[] | select(.key | startswith($project))]' "$repos_file" > "${repos_file}.filtered" 2>/dev/null && [[ -s "${repos_file}.filtered" ]]; then
        echo "✅ PREFIX FILTER PASSED"
        
        echo "Repositories that passed prefix filter:"
        jq -r '.[] | .key' "${repos_file}.filtered"
        
        mv "${repos_file}.filtered" "$repos_file"
    else
        echo "❌ PREFIX FILTER FAILED"
        
        # Test final fallback: projectKey field (line 261)
        echo ""
        echo "🧪 TESTING FINAL FALLBACK: PROJECT KEY FIELD"
        echo "============================================="
        echo "Filter: jq '[.[] | select(.projectKey == \"$PROJECT_KEY\")]'"
        
        if jq --arg project "$PROJECT_KEY" '[.[] | select(.projectKey == $project)]' "$repos_file" > "${repos_file}.filtered" 2>/dev/null && [[ -s "${repos_file}.filtered" ]]; then
            echo "✅ PROJECTKEY FILTER PASSED"
            
            echo "Repositories that passed projectKey filter:"
            jq -r '.[] | .key' "${repos_file}.filtered"
            
            mv "${repos_file}.filtered" "$repos_file"
        else
            echo "❌ ALL FILTERS FAILED"
            echo "Writing empty array to file..."
            echo "[]" > "$repos_file"
        fi
    fi
fi

echo ""
echo "🔍 FINAL FILE ANALYSIS (Lines 272-277)"
echo "======================================"

# Test the final condition (line 272)
echo "Testing: if [[ -s \"$repos_file\" ]]"
if [[ -s "$repos_file" ]]; then
    echo "✅ File has content (size: $(wc -c < "$repos_file") bytes)"
    
    echo ""
    echo "Final file content:"
    cat "$repos_file"
    
    echo ""
    echo "🚨 EXTRACTING REPOSITORY KEYS (Line 277):"
    echo "=========================================="
    
    # This is the critical line that determines what gets deleted
    jq -r '.[] | .key' "$repos_file" > "$TEMP_DEBUG/final_repos_to_delete.txt"
    
    final_count=$(wc -l < "$TEMP_DEBUG/final_repos_to_delete.txt" 2>/dev/null || echo 0)
    echo "Final repositories to delete: $final_count"
    
    if [[ "$final_count" -gt 0 ]]; then
        echo ""
        echo "🚨 REPOSITORIES THAT WOULD BE DELETED:"
        echo "====================================="
        cat "$TEMP_DEBUG/final_repos_to_delete.txt"
        
        echo ""
        echo "🔍 SAFETY CHECK:"
        echo "================"
        dangerous_repos=0
        while IFS= read -r repo; do
            if [[ "$repo" == *"bookverse"* ]]; then
                echo "  ✅ $repo (safe)"
            else
                echo "  🚨 $repo (DANGEROUS - no bookverse!)"
                ((dangerous_repos++))
            fi
        done < "$TEMP_DEBUG/final_repos_to_delete.txt"
        
        if [[ "$dangerous_repos" -gt 0 ]]; then
            echo ""
            echo "🚨 ROOT CAUSE CONFIRMED!"
            echo "========================"
            echo "Filter logic allowed $dangerous_repos non-bookverse repositories"
            echo "This matches user report of carmit-*, catalina-* deletion"
        fi
    fi
else
    echo "❌ File is empty or doesn't exist"
fi

echo ""
echo "🎯 RCA RESULTS"
echo "=============="
echo "Debug files in: $TEMP_DEBUG"
echo ""

# Show what was tested
echo "Files created:"
ls -la "$TEMP_DEBUG/"
