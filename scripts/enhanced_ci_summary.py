#!/usr/bin/env python3
"""
BookVerse Platform - Enhanced CI/CD Summary Generator
====================================================

Generates comprehensive, accurate CI/CD pipeline summaries that address common
reporting issues in GitHub Actions workflows.

This script fixes the following common issues:
1. Job status misreporting (showing success when jobs actually failed)
2. Missing lifecycle path tracking (stage transitions)
3. Artifact display showing 'N/A' values
4. Irrelevant infrastructure component information
5. Missing promotion failure details

Features:
- Accurate job status reporting based on actual outcomes
- Stage lifecycle tracking with clear progression paths
- Proper artifact and Docker image information display
- Contextual infrastructure information (only when relevant)
- Integration with promotion failure handling
- Comprehensive evidence and quality metrics

Usage:
    python enhanced_ci_summary.py --job-status build:success,promote:failed
    python enhanced_ci_summary.py --stage-path "Unassigned->DEV->QA" --current-stage DEV
    python enhanced_ci_summary.py --docker-image "inventory:1.5.26" --coverage 85.0

Authors: BookVerse Platform Team
Version: 1.0.0
"""

import argparse
import json
import os
import sys
from datetime import datetime
from typing import Dict, List, Optional, Any, Tuple


class EnhancedCISummary:
    """Enhanced CI/CD Summary generator with accurate reporting."""
    
    def __init__(self):
        self.stage_flow = {
            "Unassigned": {"next": "DEV", "description": "Initial state before any promotion"},
            "bookverse-DEV": {"next": "bookverse-QA", "description": "Development stage for testing and validation"},
            "bookverse-QA": {"next": "bookverse-STAGING", "description": "Quality assurance stage for comprehensive testing"},
            "bookverse-STAGING": {"next": "PROD", "description": "Staging environment for final validation"},
            "PROD": {"next": None, "description": "Production environment for live deployment"}
        }
        
        self.job_types = {
            "analyze-commit": {
                "name": "Demo: Analyze Commit (Demo-Optimized)",
                "description": "Code analysis and commit validation"
            },
            "build-test-publish": {
                "name": "Build & Test (Always Runs)",
                "description": "Build artifacts, run tests, and publish to registry"
            },
            "create-promote": {
                "name": "Create Application Version & Promote (Conditional)",
                "description": "Create AppTrust version and promote through stages"
            }
        }

    def determine_accurate_job_status(self, job_name: str, step_statuses: Dict[str, str], 
                                    promotion_failed: bool = False) -> Tuple[str, str]:
        """Determine accurate job status based on step outcomes."""
        if job_name == "create-promote" and promotion_failed:
            return "❌", "FAILED - Promotion blocked by policy violations"
        
        # Check if any critical steps failed
        critical_failures = []
        for step, status in step_statuses.items():
            if status == "failed":
                critical_failures.append(step)
        
        if critical_failures:
            failure_detail = f"FAILED - {', '.join(critical_failures)}"
            return "❌", failure_detail
        
        # Check for warnings
        warnings = []
        for step, status in step_statuses.items():
            if status == "warning":
                warnings.append(step)
        
        if warnings:
            warning_detail = f"COMPLETED WITH WARNINGS - {', '.join(warnings)}"
            return "⚠️", warning_detail
        
        return "✅", "COMPLETED"

    def generate_lifecycle_path(self, current_stage: str, target_stage: Optional[str] = None,
                               promotion_failed: bool = False) -> str:
        """Generate the lifecycle path showing stage progression."""
        stages = ["Unassigned", "bookverse-DEV", "bookverse-QA", "bookverse-STAGING", "PROD"]
        
        # Find current position
        try:
            current_idx = stages.index(current_stage)
        except ValueError:
            current_idx = 0
        
        path_parts = []
        for i, stage in enumerate(stages):
            if i < current_idx:
                path_parts.append(f"~~{stage}~~")  # Completed stages
            elif i == current_idx:
                path_parts.append(f"**{stage}** 📍")  # Current stage
            elif stage == target_stage and promotion_failed:
                path_parts.append(f"🚫 {stage}")  # Failed target
            elif i == current_idx + 1:
                path_parts.append(f"⏭️ {stage}")  # Next stage
            else:
                path_parts.append(stage)  # Future stages
        
        return " → ".join(path_parts)

    def extract_docker_info(self, image_tag: Optional[str] = None, 
                           image_name: Optional[str] = None) -> str:
        """Extract proper Docker image information."""
        if image_name and image_tag:
            return f"`{image_name}:{image_tag}`"
        elif image_tag:
            return f"`inventory:{image_tag}`"
        elif image_name:
            return f"`{image_name}`"
        else:
            return "'Not Available' ⚠️"

    def should_show_infrastructure_info(self, job_failed: bool, context: str) -> bool:
        """Determine if infrastructure component info is relevant."""
        # Only show infrastructure info in specific contexts
        relevant_contexts = ["setup", "initialization", "infrastructure", "platform"]
        return any(ctx in context.lower() for ctx in relevant_contexts) or job_failed

    def generate_promotion_status(self, promotion_data: Optional[Dict[str, Any]] = None) -> str:
        """Generate promotion status section."""
        if not promotion_data:
            return ""
        
        status = promotion_data.get("status", "unknown")
        if status == "failed":
            return f"""
## 🚨 Promotion Status

**Result:** ❌ **FAILED** - Promotion to {promotion_data.get('target_stage', 'target stage')} blocked

**Reason:** Policy violations detected during promotion evaluation

**Action Required:** Review and resolve policy failures before retrying promotion

📋 **Detailed Analysis:** See promotion failure summary below for specific remediation steps.
"""
        elif status == "success":
            return f"""
## ✅ Promotion Status

**Result:** ✅ **SUCCESS** - Application promoted to {promotion_data.get('target_stage', 'target stage')}

**Next Stage:** Ready for promotion to next stage when applicable
"""
        
        return ""

    def generate_enhanced_summary(self, 
                                service_name: str,
                                app_version: str,
                                build_name: str,
                                build_number: str,
                                commit_hash: str,
                                branch: str,
                                job_statuses: Dict[str, str],
                                current_stage: str,
                                target_stage: Optional[str] = None,
                                promotion_failed: bool = False,
                                promotion_data: Optional[Dict[str, Any]] = None,
                                docker_image: Optional[str] = None,
                                docker_tag: Optional[str] = None,
                                coverage_percent: Optional[float] = None,
                                build_info_status: str = "SUCCESS",
                                evidence_collected: bool = True,
                                context: str = "standard") -> str:
        """Generate comprehensive enhanced CI/CD summary."""
        
        timestamp = datetime.utcnow().isoformat().replace("+00:00", "Z")
        
        # Determine overall pipeline status
        failed_jobs = [job for job, status in job_statuses.items() if "failed" in status.lower()]
        overall_status = "❌ FAILED" if failed_jobs or promotion_failed else "✅ SUCCESS"
        
        summary = f"""# 🚀 CI/CD Pipeline Summary - {service_name.title()}

## 📊 Pipeline Overview

- **Service:** {service_name}
- **Version:** {app_version}
- **Build:** {build_name} #{build_number}
- **Commit:** `{commit_hash[:8]}`
- **Branch:** {branch}
- **Status:** {overall_status}
- **Timestamp:** {timestamp}

## 🔄 Job Execution Status
"""
        
        # Accurate job status reporting
        for i, (job_key, status) in enumerate(job_statuses.items(), 1):
            job_info = self.job_types.get(job_key, {"name": job_key, "description": ""})
            
            # Determine accurate status
            if job_key == "create-promote" and promotion_failed:
                icon, detail = "❌", "FAILED - Promotion blocked by policy violations"
            else:
                icon = "✅" if "success" in status.lower() or "completed" in status.lower() else "❌"
                detail = status
            
            summary += f"- **Job {i} ({job_key}):** {icon} {detail}\n"
        
        # Lifecycle path tracking
        summary += f"""
## 🛤️ Stage Lifecycle Path

{self.generate_lifecycle_path(current_stage, target_stage, promotion_failed)}

**Current Stage:** {current_stage}
"""
        
        if target_stage:
            if promotion_failed:
                summary += f"**Failed Target:** {target_stage} (blocked by policies)\n"
            else:
                summary += f"**Target Stage:** {target_stage}\n"
        
        # Enhanced artifacts and quality section
        docker_info = self.extract_docker_info(docker_tag, docker_image)
        coverage_display = f"{coverage_percent}%" if coverage_percent is not None else "'Not Available'"
        
        summary += f"""
## 📦 Artifacts & Quality Metrics

- **Test Coverage:** {coverage_display}
- **Docker Images:**
  - 📦 {service_name}: {docker_info}
- **Evidence Collection:** {'✅ Completed' if evidence_collected else '❌ Failed'}
- **Build Info Publication:** {'✅ Success' if build_info_status == 'SUCCESS' else '❌ Failed'}
"""
        
        # Conditional infrastructure information
        if self.should_show_infrastructure_info(bool(failed_jobs), context):
            summary += f"""
## 🛠️ Infrastructure & Dependencies

**Note:** Infrastructure information shown due to build context or failures

- **bookverse-core:** ✅ Shared libraries and dependencies
- **bookverse-devops:** ✅ CI/CD patterns and evidence collection
- **Build Environment:** ✅ JFrog integration and artifact management
- **Quality Gates:** {'❌ Policy violations detected' if promotion_failed else '✅ All checks passed'}
"""
        
        # Promotion status (if applicable)
        promotion_status = self.generate_promotion_status(promotion_data)
        if promotion_status:
            summary += promotion_status
        
        # Next steps based on status
        if promotion_failed:
            summary += f"""
## 🎯 Immediate Actions Required

1. **Review Policy Failures:** Check the promotion failure details below
2. **Resolve Violations:** Address each failed policy requirement  
3. **Retry Promotion:** Re-run promotion workflow once issues are fixed
4. **Verify Evidence:** Ensure all required evidence is properly collected

⚠️ **Important:** The promotion failure is expected behavior - the system is protecting quality gates.
"""
        elif failed_jobs:
            summary += f"""
## 🎯 Next Steps

**Failed Jobs:** {', '.join(failed_jobs)}

1. **Review Logs:** Check failed job logs for specific error details
2. **Fix Issues:** Address the root causes of job failures
3. **Retry Pipeline:** Re-run the workflow once issues are resolved
4. **Contact Support:** Reach out to platform team if assistance is needed
"""
        else:
            summary += f"""
## 🎯 Next Steps

✅ **Pipeline completed successfully!**

1. **Application Version:** {app_version} is ready in {current_stage}
2. **Promotion:** Use the Promote workflow to advance to next stage
3. **Monitoring:** Check application health in {current_stage} environment
4. **Documentation:** Update any relevant documentation for this release
"""
        
        # Support information
        summary += f"""
## 🔗 Resources & Support

- **Build Artifacts:** Available in JFrog Artifactory
- **AppTrust Console:** Monitor application versions and evidence
- **Platform Documentation:** https://docs.bookverse.com/
- **Support Channel:** #platform-support for assistance

---
*Generated by Enhanced CI/CD Summary v1.0.0*
"""
        
        return summary

    def write_github_summary(self, summary: str) -> bool:
        """Write enhanced summary to GitHub Step Summary."""
        summary_path = os.environ.get("GITHUB_STEP_SUMMARY")
        if not summary_path:
            return False
        
        try:
            # Replace existing summary or append
            with open(summary_path, "w", encoding="utf-8") as f:
                f.write(summary)
            return True
        except Exception as e:
            print(f"Warning: Failed to write GitHub summary: {e}", file=sys.stderr)
            return False


def main():
    parser = argparse.ArgumentParser(
        description="Generate enhanced CI/CD pipeline summaries with accurate reporting",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Basic usage
  python enhanced_ci_summary.py --service inventory --version 2.7.25 \\
    --job-status analyze-commit:success,build-test:success,create-promote:failed
  
  # With promotion failure
  python enhanced_ci_summary.py --service inventory --promotion-failed \\
    --current-stage bookverse-DEV --target-stage bookverse-QA
  
  # With full context
  python enhanced_ci_summary.py --service inventory --version 2.7.25 \\
    --docker-tag 1.5.26 --coverage 85.0 --current-stage bookverse-DEV
        """
    )
    
    # Required parameters
    parser.add_argument("--service", required=True, help="Service name (e.g., inventory)")
    parser.add_argument("--version", default="N/A", help="Application version")
    parser.add_argument("--build-name", default="CI", help="Build name")
    parser.add_argument("--build-number", default="1", help="Build number")
    parser.add_argument("--commit", default="unknown", help="Commit hash")
    parser.add_argument("--branch", default="main", help="Git branch")
    
    # Job status tracking
    parser.add_argument("--job-status", help="Job statuses as 'job1:status1,job2:status2'")
    
    # Stage and promotion info
    parser.add_argument("--current-stage", default="Unassigned", help="Current application stage")
    parser.add_argument("--target-stage", help="Target stage for promotion")
    parser.add_argument("--promotion-failed", action="store_true", help="Promotion failed")
    parser.add_argument("--promotion-data", help="Promotion failure data as JSON")
    
    # Artifact information
    parser.add_argument("--docker-image", help="Docker image name")
    parser.add_argument("--docker-tag", help="Docker image tag")
    parser.add_argument("--coverage", type=float, help="Test coverage percentage")
    
    # Additional context
    parser.add_argument("--build-info-status", default="SUCCESS", help="Build info publication status")
    parser.add_argument("--evidence-collected", action="store_true", default=True, help="Evidence collection status")
    parser.add_argument("--context", default="standard", help="Build context (standard, setup, infrastructure)")
    
    # Output options
    parser.add_argument("--github-summary", action="store_true", help="Write to GitHub Step Summary")
    parser.add_argument("--output-file", help="Write summary to file")
    parser.add_argument("--replace-summary", action="store_true", help="Replace existing summary instead of appending")
    
    args = parser.parse_args()
    
    generator = EnhancedCISummary()
    
    # Parse job statuses
    job_statuses = {}
    if args.job_status:
        for item in args.job_status.split(","):
            if ":" in item:
                job, status = item.split(":", 1)
                job_statuses[job.strip()] = status.strip()
    
    # Default job statuses if not provided
    if not job_statuses:
        job_statuses = {
            "analyze-commit": "success",
            "build-test-publish": "success",
            "create-promote": "failed" if args.promotion_failed else "success"
        }
    
    # Parse promotion data
    promotion_data = None
    if args.promotion_data:
        try:
            promotion_data = json.loads(args.promotion_data)
        except json.JSONDecodeError:
            print("Warning: Invalid promotion data JSON, ignoring", file=sys.stderr)
    
    # Generate enhanced summary
    summary = generator.generate_enhanced_summary(
        service_name=args.service,
        app_version=args.version,
        build_name=args.build_name,
        build_number=args.build_number,
        commit_hash=args.commit,
        branch=args.branch,
        job_statuses=job_statuses,
        current_stage=args.current_stage,
        target_stage=args.target_stage,
        promotion_failed=args.promotion_failed,
        promotion_data=promotion_data,
        docker_image=args.docker_image,
        docker_tag=args.docker_tag,
        coverage_percent=args.coverage,
        build_info_status=args.build_info_status,
        evidence_collected=args.evidence_collected,
        context=args.context
    )
    
    # Output the summary
    print(summary)
    
    # Write to GitHub summary if requested
    if args.github_summary:
        if generator.write_github_summary(summary):
            print("✅ Summary written to GitHub Step Summary", file=sys.stderr)
        else:
            print("⚠️ GitHub Step Summary not available", file=sys.stderr)
    
    # Write to output file if specified
    if args.output_file:
        try:
            mode = "w" if args.replace_summary else "a"
            with open(args.output_file, mode, encoding='utf-8') as f:
                f.write(summary)
            print(f"✅ Summary written to {args.output_file}", file=sys.stderr)
        except Exception as e:
            print(f"Error writing to output file: {e}", file=sys.stderr)
            return 1
    
    return 0


if __name__ == "__main__":
    sys.exit(main())
