#!/usr/bin/env python3
"""
BookVerse Platform - Promotion Policy Failure Handler
=====================================================

Handles policy evaluation failures during application promotions and creates
comprehensive job summaries with actionable guidance for fixing policy violations.

This script processes promotion failure data and creates detailed GitHub job summaries
that help developers understand what went wrong and how to fix the issues.

Features:
- Parse promotion failure JSON output
- Identify specific failed policies
- Generate actionable remediation guidance
- Create formatted GitHub step summaries
- Support for different failure types and stages

Usage:
    python handle_promotion_failure.py --failure-json '{"application_key":...}'
    python handle_promotion_failure.py --failure-file failure.json
    echo '{"application_key":...}' | python handle_promotion_failure.py --stdin

Authors: BookVerse Platform Team
Version: 1.0.0
"""

import argparse
import json
import os
import sys
from datetime import datetime
from typing import Dict, List, Optional, Any


class PromotionFailureHandler:
    """Handles promotion policy failures and generates actionable summaries."""
    
    def __init__(self):
        self.policy_guidance = {
            # Evidence-related policies
            "BookVerse QA Entry Gate - Evidence Required": {
                "description": "Requires evidence of successful DEV stage completion",
                "required_evidence": "DEV.Exit AppTrust Gate Certification",
                "actions": [
                    "Ensure the application completed all DEV stage requirements",
                    "Verify DEV stage exit gate evaluation passed",
                    "Check AppTrust for DEV.Exit certification evidence",
                    "If missing, complete DEV stage testing and validation"
                ],
                "docs_link": "https://docs.bookverse.com/quality-gates/dev-completion"
            },
            "BookVerse QA Entry Gate - SBOM Required": {
                "description": "Requires Software Bill of Materials (SBOM) evidence",
                "required_evidence": "CycloneDX SBOM from build pipeline",
                "actions": [
                    "Check if SBOM was generated during the build process",
                    "Verify build pipeline includes SBOM generation step",
                    "Ensure SBOM is properly uploaded to AppTrust",
                    "Re-run build if SBOM generation failed"
                ],
                "docs_link": "https://docs.bookverse.com/security/sbom-requirements"
            },
            "BookVerse QA Entry - Custom Integration Tests": {
                "description": "Requires custom integration test evidence",
                "required_evidence": "Integration test results and coverage",
                "actions": [
                    "Run the complete integration test suite",
                    "Ensure all integration tests pass",
                    "Upload test results to evidence collection system",
                    "Verify test coverage meets minimum requirements"
                ],
                "docs_link": "https://docs.bookverse.com/testing/integration-tests"
            },
            "BookVerse QA Entry - STAGING Check (Demo Failure)": {
                "description": "Demo policy - checks for inappropriate STAGING evidence",
                "required_evidence": "STAGING evidence should NOT exist at QA entry",
                "actions": [
                    "This is a demo policy designed to fail",
                    "No action needed - this demonstrates policy evaluation",
                    "In real scenarios, this would check staging prerequisites",
                    "Contact platform team if you see this in production"
                ],
                "docs_link": "https://docs.bookverse.com/demo/policy-scenarios"
            },
            "BookVerse QA Entry - Prod Readiness (Demo Failure)": {
                "description": "Demo policy - checks for production readiness evidence",
                "required_evidence": "Production readiness evidence (not expected at QA)",
                "actions": [
                    "This is a demo policy designed to fail",
                    "No action needed - this demonstrates policy evaluation",
                    "Production readiness is evaluated later in the lifecycle",
                    "Contact platform team if you see this in production"
                ],
                "docs_link": "https://docs.bookverse.com/demo/policy-scenarios"
            }
        }
        
        # Get PROJECT_KEY from environment, default to "bookverse" for backward compatibility
        project_key = os.environ.get("PROJECT_KEY", "bookverse")
        
        self.stage_guidance = {
            f"{project_key}-DEV": {
                "description": "Development stage for initial testing and validation",
                "typical_evidence": ["Build artifacts", "Unit tests", "Security scans"],
                "exit_requirements": ["All tests pass", "Security scan clean", "Code review complete"]
            },
            f"{project_key}-QA": {
                "description": "Quality assurance stage for comprehensive testing",
                "typical_evidence": ["Integration tests", "Performance tests", "SBOM"],
                "entry_requirements": ["DEV stage complete", "Evidence collection", "Policy compliance"]
            },
            f"{project_key}-STAGING": {
                "description": "Staging environment for final validation",
                "typical_evidence": ["E2E tests", "Load tests", "UAT results"],
                "entry_requirements": ["QA stage complete", "Full test coverage", "Performance validation"]
            },
            "PROD": {
                "description": "Production stage for live deployment",
                "typical_evidence": ["Production readiness", "Deployment checklist", "Monitoring setup"],
                "entry_requirements": ["All previous stages complete", "Production readiness", "Approval workflows"]
            }
        }

    def parse_failure_data(self, failure_json: str) -> Dict[str, Any]:
        """Parse the promotion failure JSON data."""
        try:
            data = json.loads(failure_json)
            return data
        except json.JSONDecodeError as e:
            raise ValueError(f"Invalid JSON format: {e}")

    def extract_failed_policies(self, failure_data: Dict[str, Any]) -> List[str]:
        """Extract the list of failed policies from the failure data."""
        failed_policies = []
        
        evaluations = failure_data.get("evaluations", {})
        entry_gate = evaluations.get("entry_gate", {})
        
        if entry_gate.get("decision") == "fail":
            explanation = entry_gate.get("explanation", "")
            # Extract policy names from the explanation string
            # Example: "violated policies: [Policy1], [Policy2], [Policy3]"
            if "violated policies:" in explanation:
                policies_part = explanation.split("violated policies:")[1]
                # Extract policy names between square brackets
                import re
                policy_matches = re.findall(r'\[([^\]]+)\]', policies_part)
                failed_policies.extend(policy_matches)
        
        return failed_policies

    def generate_remediation_guidance(self, failed_policies: List[str]) -> str:
        """Generate detailed remediation guidance for failed policies."""
        guidance_sections = []
        
        for policy in failed_policies:
            if policy in self.policy_guidance:
                guidance = self.policy_guidance[policy]
                section = f"""
### 🚨 {policy}

**Issue:** {guidance['description']}

**Required Evidence:** {guidance['required_evidence']}

**Actions to Fix:**
"""
                for i, action in enumerate(guidance['actions'], 1):
                    section += f"{i}. {action}\n"
                
                section += f"\n📖 **Documentation:** {guidance['docs_link']}\n"
                guidance_sections.append(section)
            else:
                # Generic guidance for unknown policies
                section = f"""
### 🚨 {policy}

**Issue:** Policy violation detected

**Actions to Fix:**
1. Review the policy requirements in AppTrust console
2. Check what evidence is required for this policy
3. Ensure all required evidence is properly uploaded
4. Contact the platform team if you need assistance

📖 **Documentation:** https://docs.bookverse.com/policies/overview
"""
                guidance_sections.append(section)
        
        return "\n".join(guidance_sections)

    def generate_stage_information(self, source_stage: str, target_stage: str) -> str:
        """Generate information about the source and target stages."""
        info = f"""
## 📊 Stage Transition Information

### Source Stage: {source_stage}
"""
        if source_stage in self.stage_guidance:
            stage_info = self.stage_guidance[source_stage]
            info += f"- **Purpose:** {stage_info['description']}\n"
            info += f"- **Typical Evidence:** {', '.join(stage_info['typical_evidence'])}\n"
            if 'exit_requirements' in stage_info:
                info += f"- **Exit Requirements:** {', '.join(stage_info['exit_requirements'])}\n"

        info += f"""
### Target Stage: {target_stage}
"""
        if target_stage in self.stage_guidance:
            stage_info = self.stage_guidance[target_stage]
            info += f"- **Purpose:** {stage_info['description']}\n"
            if 'entry_requirements' in stage_info:
                info += f"- **Entry Requirements:** {', '.join(stage_info['entry_requirements'])}\n"
        
        return info

    def generate_summary(self, failure_data: Dict[str, Any]) -> str:
        """Generate a comprehensive job summary for the promotion failure."""
        app_key = failure_data.get("application_key", "unknown")
        version = failure_data.get("version", "unknown")
        source_stage = failure_data.get("source_stage", "unknown")
        target_stage = failure_data.get("target_stage", "unknown")
        promotion_type = failure_data.get("promotion_type", "move")
        message = failure_data.get("message", "Promotion failed due to policy violations")
        
        failed_policies = self.extract_failed_policies(failure_data)
        
        # Build the summary
        summary = f"""# 🚨 Promotion Failed: {app_key} v{version}

## 📋 Promotion Summary

- **Application:** {app_key}
- **Version:** {version}
- **Source Stage:** {source_stage}
- **Target Stage:** {target_stage}
- **Promotion Type:** {promotion_type}
- **Status:** ❌ **FAILED**
- **Timestamp:** {datetime.utcnow().isoformat()}Z

## ❌ Failure Details

{message}

**Evaluation Results:**
"""
        
        evaluations = failure_data.get("evaluations", {})
        
        # Exit gate status
        exit_gate = evaluations.get("exit_gate", {})
        if exit_gate:
            decision = exit_gate.get("decision", "unknown")
            eval_id = exit_gate.get("eval_id", "N/A")
            stage = exit_gate.get("stage", source_stage)
            status_emoji = "✅" if decision == "pass" else "❌"
            summary += f"- **{stage} Exit Gate:** {status_emoji} {decision.upper()} (ID: {eval_id})\n"
        
        # Entry gate status
        entry_gate = evaluations.get("entry_gate", {})
        if entry_gate:
            decision = entry_gate.get("decision", "unknown")
            eval_id = entry_gate.get("eval_id", "N/A")
            stage = entry_gate.get("stage", target_stage)
            status_emoji = "✅" if decision == "pass" else "❌"
            summary += f"- **{stage} Entry Gate:** {status_emoji} {decision.upper()} (ID: {eval_id})\n"
            
            explanation = entry_gate.get("explanation", "")
            if explanation:
                summary += f"- **Failure Reason:** {explanation}\n"

        # Failed policies section
        if failed_policies:
            summary += f"""
## 🔧 Required Actions

The following {len(failed_policies)} policies failed and must be addressed before promotion can succeed:

{self.generate_remediation_guidance(failed_policies)}
"""
        
        # Stage information
        summary += self.generate_stage_information(source_stage, target_stage)
        
        # Next steps
        summary += f"""
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
"""
        
        return summary

    def write_github_summary(self, summary: str) -> bool:
        """Write the summary to GitHub Step Summary if available."""
        summary_path = os.environ.get("GITHUB_STEP_SUMMARY")
        if not summary_path:
            return False
        
        try:
            with open(summary_path, "a", encoding="utf-8") as f:
                f.write("\n" + summary + "\n")
            return True
        except Exception as e:
            print(f"Warning: Failed to write GitHub summary: {e}", file=sys.stderr)
            return False


def main():
    parser = argparse.ArgumentParser(
        description="Handle promotion policy failures and generate job summaries",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # From command line JSON
  python handle_promotion_failure.py --failure-json '{"application_key":"bookverse-inventory",...}'
  
  # From file
  python handle_promotion_failure.py --failure-file failure.json
  
  # From stdin
  echo '{"application_key":...}' | python handle_promotion_failure.py --stdin
  
  # Write to GitHub summary and stdout
  python handle_promotion_failure.py --failure-json '...' --github-summary
        """
    )
    
    input_group = parser.add_mutually_exclusive_group(required=True)
    input_group.add_argument(
        "--failure-json",
        help="Promotion failure data as JSON string"
    )
    input_group.add_argument(
        "--failure-file",
        help="Path to file containing promotion failure JSON"
    )
    input_group.add_argument(
        "--stdin",
        action="store_true",
        help="Read promotion failure JSON from stdin"
    )
    
    parser.add_argument(
        "--github-summary",
        action="store_true",
        help="Write summary to GitHub Step Summary (if GITHUB_STEP_SUMMARY env var is set)"
    )
    parser.add_argument(
        "--output-file",
        help="Write summary to specified file"
    )
    parser.add_argument(
        "--verbose",
        action="store_true",
        help="Enable verbose output"
    )
    
    args = parser.parse_args()
    
    handler = PromotionFailureHandler()
    
    # Get the failure data
    try:
        if args.failure_json:
            failure_data = handler.parse_failure_data(args.failure_json)
        elif args.failure_file:
            with open(args.failure_file, 'r', encoding='utf-8') as f:
                failure_data = handler.parse_failure_data(f.read())
        elif args.stdin:
            failure_data = handler.parse_failure_data(sys.stdin.read())
    except Exception as e:
        print(f"Error reading failure data: {e}", file=sys.stderr)
        return 1
    
    if args.verbose:
        print(f"Processing failure for: {failure_data.get('application_key')} v{failure_data.get('version')}")
    
    # Generate the summary
    try:
        summary = handler.generate_summary(failure_data)
    except Exception as e:
        print(f"Error generating summary: {e}", file=sys.stderr)
        return 1
    
    # Output the summary
    print(summary)
    
    # Write to GitHub summary if requested
    if args.github_summary:
        if handler.write_github_summary(summary):
            if args.verbose:
                print("✅ Written to GitHub Step Summary", file=sys.stderr)
        else:
            if args.verbose:
                print("⚠️ GitHub Step Summary not available", file=sys.stderr)
    
    # Write to output file if specified
    if args.output_file:
        try:
            with open(args.output_file, 'w', encoding='utf-8') as f:
                f.write(summary)
            if args.verbose:
                print(f"✅ Written to {args.output_file}", file=sys.stderr)
        except Exception as e:
            print(f"Error writing to output file: {e}", file=sys.stderr)
            return 1
    
    return 0


if __name__ == "__main__":
    sys.exit(main())
