#!/usr/bin/env python3
"""
Evidence Generator for BookVerse Demo - Testing Version
"""

import os
import sys
import subprocess
from pathlib import Path
from datetime import datetime

class EvidenceGenerator:
    def __init__(self):
        self.evidence_dir = Path(__file__).parent.parent / "evidence"
        self.templates_dir = self.evidence_dir / "templates"
        
    def _get_environment_variables(self):
        """Get common environment variables for template substitution"""
        now = datetime.utcnow()
        
        return {
            'NOW_TS': now.strftime('%Y-%m-%dT%H:%M:%SZ'),
            'SERVICE_NAME': os.getenv('SERVICE_NAME', 'test-service'),
            'APP_VERSION': os.getenv('APP_VERSION', '1.0.0'),
            'BUILD_NUMBER': os.getenv('BUILD_NUMBER', '42'),
            'BUILD_NAME': os.getenv('BUILD_NAME', 'test-service'),
            'APPLICATION_KEY': os.getenv('APPLICATION_KEY', 'bookverse-test-service'),
        }
    
    def generate_package_evidence(self, package_type, evidence_type):
        """Generate package-level evidence"""
        template_file = self.templates_dir / "package" / package_type / f"{evidence_type}.json.template"
        
        if not template_file.exists():
            print(f"❌ Template not found: {template_file}")
            return None
            
        return self._process_template(template_file, f"{evidence_type}.json")
    
    def generate_build_evidence(self, evidence_type):
        """Generate build-level evidence"""
        template_file = self.templates_dir / "build" / f"{evidence_type}.json.template"
        
        if not template_file.exists():
            print(f"❌ Template not found: {template_file}")
            return None
            
        return self._process_template(template_file, f"{evidence_type}.json")
    
    def generate_application_evidence(self, stage, evidence_type):
        """Generate application-level evidence"""
        template_file = self.templates_dir / "application" / stage / f"{evidence_type}.json.template"
        
        if not template_file.exists():
            print(f"❌ Template not found: {template_file}")
            return None
            
        return self._process_template(template_file, f"{evidence_type}.json")
    
    def _process_template(self, template_path, output_filename):
        """Process a template file with environment variable substitution"""
        try:
            # Read template
            with open(template_path, 'r') as f:
                template_content = f.read()
            
            # Set environment variables
            env = os.environ.copy()
            env.update(self._get_environment_variables())
            
            # Simple variable substitution (for testing)
            result_content = template_content
            for key, value in env.items():
                result_content = result_content.replace(f"${{{key}}}", str(value))
                result_content = result_content.replace(f"${{{key}:-", f"{value}").replace("}", "")
            
            # Write output file
            output_path = Path.cwd() / output_filename
            with open(output_path, 'w') as f:
                f.write(result_content)
            
            print(f"✅ Generated: {output_filename}")
            return str(output_path)
            
        except Exception as e:
            print(f"❌ Error processing template {template_path}: {e}")
            return None

def main():
    """Simple CLI for testing"""
    if len(sys.argv) < 4:
        print("Usage: python evidence-generator.py <package|build|application> <type|stage> <evidence_name>")
        print("\nExamples:")
        print("  python evidence-generator.py package docker pytest-results")
        print("  python evidence-generator.py build - fossa-license-scan")
        print("  python evidence-generator.py application unassigned slsa-provenance")
        sys.exit(1)
    
    generator = EvidenceGenerator()
    
    category = sys.argv[1]
    type_or_stage = sys.argv[2]
    evidence_name = sys.argv[3]
    
    if category == "package":
        result = generator.generate_package_evidence(type_or_stage, evidence_name)
    elif category == "build":
        result = generator.generate_build_evidence(evidence_name)
    elif category == "application":
        result = generator.generate_application_evidence(type_or_stage, evidence_name)
    else:
        print(f"❌ Unknown category: {category}")
        sys.exit(1)
    
    if result:
        print(f"🎯 Evidence generated successfully: {result}")
    else:
        print("❌ Evidence generation failed")
        sys.exit(1)

if __name__ == "__main__":
    main()
