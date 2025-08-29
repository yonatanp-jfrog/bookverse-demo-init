# 🚨 CRITICAL SECURITY VULNERABILITIES FOUND

## Summary
The cleanup scripts contain **CRITICAL SECURITY BUGS** that delete resources outside the intended project scope.

## ❌ Bug 1: Repository Deletion Outside Project

**File:** `cleanup_project_based.sh`  
**Line:** 245  
**Code:** 
```bash
jq --arg project "$PROJECT_KEY" '[.[] | select(.key | contains($project))]'
```

**Problem:** Deletes ANY repository with "bookverse" anywhere in the name, regardless of project ownership.

**Dangerous Examples:**
- ✅ `bookverse-demo` (intended)
- ❌ `critical-bookverse-production` (other project!) 
- ❌ `legacy-bookverse-backup` (other project!)
- ❌ `test-bookverse-experimental` (other project!)

## ❌ Bug 2: Build Deletion Outside Project  

**File:** `cleanup_project_based.sh`  
**Function:** `discover_project_builds()`  

**Problem:** When project API returns 404/empty, script may have fallback logic that uses unfiltered build discovery.

**Evidence:** User reported `Commons-Build` and `evd` being deleted (these don't belong to bookverse project).

## 🎯 Root Cause

**Using name-based filtering instead of project membership verification.**

The original user requirement was clear:
> "the cleanup logic should not count on the resources names to contain the word bookverse. Instead it should look for resources in the bookverse project regardless of the name."

## ✅ Required Fixes

### 1. Repository Discovery
- **Current:** Filter by name containing "bookverse"  
- **Required:** Use proper JFrog project API that returns only project repositories
- **API:** Should use project-specific endpoints that return resources by membership

### 2. Build Discovery  
- **Current:** Project API + potential fallback  
- **Required:** Only use project-filtered APIs, no fallbacks to unfiltered lists
- **Safety:** If project API fails, return 0 (no builds), don't delete anything

### 3. Verification Step
- **Required:** Before deleting ANY resource, verify it belongs to the project
- **Method:** Query the resource's project assignment via API
- **Safety:** If verification fails, skip deletion

## 🚨 Immediate Action Required

**STOP using the cleanup script until these bugs are fixed!**

1. ✅ Document the security vulnerabilities (this file)
2. 🔧 Fix repository filtering to use project membership
3. 🔧 Fix build discovery to prevent fallback deletion
4. 🔧 Add pre-deletion project verification
5. ✅ Test fixes against non-project resources
6. ✅ Deploy secure version

## Testing Plan

Before deploying fixes:

1. **Create test repositories** in different projects with "bookverse" in names
2. **Run cleanup script** and verify no cross-project deletion
3. **Verify only actual bookverse project resources are deleted**
4. **Test with empty project** (0 builds/repos) to ensure no fallback deletion

---

**Date:** 2024-08-29  
**Severity:** CRITICAL  
**Impact:** Data loss in other projects  
**Status:** IDENTIFIED, FIXING IN PROGRESS
