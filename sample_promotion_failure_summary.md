# 🚨 Promotion Failed: bookverse-inventory v2.7.24

## 📋 Promotion Summary

- **Application:** bookverse-inventory
- **Version:** 2.7.24
- **Source Stage:** bookverse-DEV
- **Target Stage:** bookverse-QA
- **Promotion Type:** move
- **Status:** ❌ **FAILED**
- **Timestamp:** 2025-09-24T13:23:23.082038Z

## ❌ Failure Details

move promotion from 'bookverse-DEV' to 'bookverse-QA' failed due to policy violations.

**Evaluation Results:**
- **bookverse-DEV Exit Gate:** ✅ PASS (ID: 1970839623010287617)
- **bookverse-QA Entry Gate:** ❌ FAIL (ID: 1970839624631857153)
- **Failure Reason:** PR Merge policy {evaluation} failed due to violated policies: [BookVerse QA Entry Gate - Evidence Required], [BookVerse QA Entry Gate - SBOM Required], [BookVerse QA Entry - Custom Integration Tests], [BookVerse QA Entry - STAGING Check (Demo Failure)], [BookVerse QA Entry - Prod Readiness (Demo Failure)].

## 🔧 Required Actions

The following 5 policies failed and must be addressed before promotion can succeed:


### 🚨 BookVerse QA Entry Gate - Evidence Required

**Issue:** Requires evidence of successful DEV stage completion

**Required Evidence:** DEV.Exit AppTrust Gate Certification

**Actions to Fix:**
1. Ensure the application completed all DEV stage requirements
2. Verify DEV stage exit gate evaluation passed
3. Check AppTrust for DEV.Exit certification evidence
4. If missing, complete DEV stage testing and validation

📖 **Documentation:** https://docs.bookverse.com/quality-gates/dev-completion


### 🚨 BookVerse QA Entry Gate - SBOM Required

**Issue:** Requires Software Bill of Materials (SBOM) evidence

**Required Evidence:** CycloneDX SBOM from build pipeline

**Actions to Fix:**
1. Check if SBOM was generated during the build process
2. Verify build pipeline includes SBOM generation step
3. Ensure SBOM is properly uploaded to AppTrust
4. Re-run build if SBOM generation failed

📖 **Documentation:** https://docs.bookverse.com/security/sbom-requirements


### 🚨 BookVerse QA Entry - Custom Integration Tests

**Issue:** Requires custom integration test evidence

**Required Evidence:** Integration test results and coverage

**Actions to Fix:**
1. Run the complete integration test suite
2. Ensure all integration tests pass
3. Upload test results to evidence collection system
4. Verify test coverage meets minimum requirements

📖 **Documentation:** https://docs.bookverse.com/testing/integration-tests


### 🚨 BookVerse QA Entry - STAGING Check (Demo Failure)

**Issue:** Demo policy - checks for inappropriate STAGING evidence

**Required Evidence:** STAGING evidence should NOT exist at QA entry

**Actions to Fix:**
1. This is a demo policy designed to fail
2. No action needed - this demonstrates policy evaluation
3. In real scenarios, this would check staging prerequisites
4. Contact platform team if you see this in production

📖 **Documentation:** https://docs.bookverse.com/demo/policy-scenarios


### 🚨 BookVerse QA Entry - Prod Readiness (Demo Failure)

**Issue:** Demo policy - checks for production readiness evidence

**Required Evidence:** Production readiness evidence (not expected at QA)

**Actions to Fix:**
1. This is a demo policy designed to fail
2. No action needed - this demonstrates policy evaluation
3. Production readiness is evaluated later in the lifecycle
4. Contact platform team if you see this in production

📖 **Documentation:** https://docs.bookverse.com/demo/policy-scenarios


## 📊 Stage Transition Information

### Source Stage: bookverse-DEV
- **Purpose:** Development stage for initial testing and validation
- **Typical Evidence:** Build artifacts, Unit tests, Security scans
- **Exit Requirements:** All tests pass, Security scan clean, Code review complete

### Target Stage: bookverse-QA
- **Purpose:** Quality assurance stage for comprehensive testing
- **Entry Requirements:** DEV stage complete, Evidence collection, Policy compliance

## 🎯 Next Steps

1. **Review Failed Policies:** Address each failed policy listed above
2. **Collect Evidence:** Ensure all required evidence is properly generated and uploaded
3. **Verify Compliance:** Check AppTrust console for evidence validation
4. **Retry Promotion:** Once all issues are resolved, retry the promotion

## 🔗 Useful Links

- **AppTrust Console:** Check evidence and policy status
- **Build Pipeline:** Re-run builds if evidence generation failed
- **Platform Documentation:** https://docs.bookverse.com/
- **Support:** Contact #platform-support for assistance

## 📞 Getting Help

If you need assistance resolving these policy failures:

1. **Check Documentation:** Review the links provided for each failed policy
2. **Platform Support:** Contact the platform team via #platform-support
3. **Evidence Review:** Use AppTrust console to verify evidence collection
4. **Policy Questions:** Reach out to the compliance team for policy clarification

---

**⚠️ Important:** This is an application-level failure that is part of the normal quality gate process. The system is working correctly by preventing promotion until all requirements are met.

