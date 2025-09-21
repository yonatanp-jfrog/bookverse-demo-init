#!/usr/bin/env python3
"""
Script to find and clean up AppTrust application versions containing faulty Docker images.
Since the faulty images are protected by Release Bundle v2 promotions, we need to 
delete the application version that contains them.
"""

import os
import sys
import json
import re
import requests
from typing import List, Dict, Optional
import argparse
from urllib.parse import urljoin

class AppTrustClient:
    def __init__(self, base_url: str, token: str, project_key: str, verbose: bool = False):
        self.base_url = base_url.rstrip('/')
        self.token = token
        self.project_key = project_key
        self.verbose = verbose
        self.session = requests.Session()
        self.session.headers.update({
            'Authorization': f'Bearer {token}',
            'Content-Type': 'application/json',
            'Accept': 'application/json'
        })

    def _log(self, message: str):
        if self.verbose:
            print(f"[DEBUG] {message}")

    def _make_request(self, method: str, endpoint: str, **kwargs) -> requests.Response:
        url = urljoin(self.base_url, endpoint)
        if self.verbose:
            print(f"[API] {method} {url}")
        
        response = self.session.request(method, url, **kwargs)
        
        if self.verbose:
            print(f"[API] Response: {response.status_code}")
            if response.status_code >= 400:
                print(f"[API] Error: {response.text}")
        
        return response

    def list_application_versions(self, app_key: str) -> List[Dict]:
        """List all versions for an application."""
        endpoint = f"/apptrust/api/v1/applications/{app_key}/versions"
        
        try:
            response = self._make_request('GET', endpoint)
            if response.status_code == 200:
                return response.json().get('versions', [])
            else:
                print(f"❌ Failed to list versions for {app_key}: HTTP {response.status_code}")
                return []
        except Exception as e:
            print(f"❌ Error listing versions for {app_key}: {e}")
            return []

    def get_version_content(self, app_key: str, version: str) -> Optional[Dict]:
        """Get detailed content of a specific application version."""
        endpoint = f"/apptrust/api/v1/applications/{app_key}/versions/{version}/content"
        
        try:
            response = self._make_request('GET', endpoint)
            if response.status_code == 200:
                return response.json()
            else:
                self._log(f"Failed to get content for {app_key}@{version}: HTTP {response.status_code}")
                return None
        except Exception as e:
            self._log(f"Error getting content for {app_key}@{version}: {e}")
            return None

    def delete_application_version(self, app_key: str, version: str) -> bool:
        """Delete a specific application version."""
        endpoint = f"/apptrust/api/v1/applications/{app_key}/versions/{version}"
        
        try:
            response = self._make_request('DELETE', endpoint)
            if response.status_code in [200, 204]:
                return True
            else:
                print(f"❌ Failed to delete {app_key}@{version}: HTTP {response.status_code}")
                print(f"   Response: {response.text}")
                return False
        except Exception as e:
            print(f"❌ Error deleting {app_key}@{version}: {e}")
            return False

    def get_version_promotions(self, app_key: str, version: str) -> List[Dict]:
        """Get promotions for a specific application version."""
        endpoint = f"/apptrust/api/v1/applications/{app_key}/versions/{version}/promotions"
        
        try:
            response = self._make_request('GET', endpoint)
            if response.status_code == 200:
                return response.json().get('promotions', [])
            else:
                self._log(f"Failed to get promotions for {app_key}@{version}: HTTP {response.status_code}")
                return []
        except Exception as e:
            self._log(f"Error getting promotions for {app_key}@{version}: {e}")
            return []

def contains_faulty_tag(content: Dict, target_tag: str = "180-1") -> bool:
    """Check if version content contains the faulty Docker tag."""
    if not content:
        return False
    
    # Check artifacts for Docker images with the faulty tag
    artifacts = content.get('artifacts', [])
    for artifact in artifacts:
        name = artifact.get('name', '')
        if target_tag in name and ('checkout' in name or 'docker' in name.lower()):
            return True
    
    return False

def main():
    parser = argparse.ArgumentParser(description='Find and clean up AppTrust versions with faulty Docker images')
    parser.add_argument('--jfrog-url', required=True, help='JFrog base URL')
    parser.add_argument('--jfrog-token', required=True, help='JFrog access token')
    parser.add_argument('--project-key', default='bookverse', help='Project key (default: bookverse)')
    parser.add_argument('--app-key', default='bookverse-checkout', help='Application key (default: bookverse-checkout)')
    parser.add_argument('--target-tag', default='180-1', help='Faulty tag to find (default: 180-1)')
    parser.add_argument('--dry-run', action='store_true', help='Show what would be deleted without actually deleting')
    parser.add_argument('--verbose', action='store_true', help='Enable verbose logging')
    
    args = parser.parse_args()
    
    # Initialize AppTrust client
    client = AppTrustClient(args.jfrog_url, args.jfrog_token, args.project_key, args.verbose)
    
    print("🔍 Scanning AppTrust application versions for faulty Docker images...")
    print(f"   JFrog URL: {args.jfrog_url}")
    print(f"   Application: {args.app_key}")
    print(f"   Target tag: {args.target_tag}")
    print(f"   Mode: {'DRY RUN' if args.dry_run else 'DELETE'}")
    print()
    
    # Get all versions for the application
    versions = client.list_application_versions(args.app_key)
    if not versions:
        print(f"❌ No versions found for application {args.app_key}")
        return 1
    
    print(f"📦 Found {len(versions)} versions for {args.app_key}")
    
    faulty_versions = []
    
    # Check each version for faulty content
    for version_info in versions:
        version = version_info.get('version', '')
        status = version_info.get('status', '')
        created = version_info.get('created', '')
        
        print(f"   🔍 Checking version {version} (status: {status}, created: {created})")
        
        # Get detailed content
        content = client.get_version_content(args.app_key, version)
        
        if contains_faulty_tag(content, args.target_tag):
            print(f"      🚨 FOUND faulty tag '{args.target_tag}' in version {version}")
            
            # Get promotions to understand the scope
            promotions = client.get_version_promotions(args.app_key, version)
            promotion_stages = [p.get('stage', '') for p in promotions]
            
            faulty_versions.append({
                'version': version,
                'status': status,
                'created': created,
                'promotions': promotion_stages,
                'content': content
            })
            
            print(f"      📋 Promoted to stages: {', '.join(promotion_stages) if promotion_stages else 'None'}")
        else:
            print(f"      ✅ Clean version (no faulty tags)")
    
    print()
    print("=" * 60)
    print("📊 SUMMARY")
    print(f"   Total versions scanned: {len(versions)}")
    print(f"   Faulty versions found: {len(faulty_versions)}")
    
    if not faulty_versions:
        print("   🎉 No versions contain the faulty Docker tag!")
        return 0
    
    # Show details of faulty versions
    for fv in faulty_versions:
        print(f"\n🚨 FAULTY VERSION: {fv['version']}")
        print(f"   Status: {fv['status']}")
        print(f"   Created: {fv['created']}")
        print(f"   Promotions: {', '.join(fv['promotions']) if fv['promotions'] else 'None'}")
        
        # Show relevant artifacts
        artifacts = fv['content'].get('artifacts', [])
        faulty_artifacts = [a for a in artifacts if args.target_tag in a.get('name', '')]
        print(f"   Faulty artifacts ({len(faulty_artifacts)}):")
        for artifact in faulty_artifacts[:5]:  # Show first 5
            print(f"      - {artifact.get('name', 'unknown')}")
        if len(faulty_artifacts) > 5:
            print(f"      ... and {len(faulty_artifacts) - 5} more")
    
    # Deletion logic
    if args.dry_run:
        print(f"\n🔍 DRY RUN: Would delete {len(faulty_versions)} faulty versions")
        for fv in faulty_versions:
            print(f"   Would delete: {args.app_key}@{fv['version']}")
    else:
        print(f"\n🗑️ DELETING {len(faulty_versions)} faulty versions...")
        deleted_count = 0
        
        for fv in faulty_versions:
            version = fv['version']
            print(f"   Deleting {args.app_key}@{version}...")
            
            if client.delete_application_version(args.app_key, version):
                print(f"   ✅ Deleted {args.app_key}@{version}")
                deleted_count += 1
            else:
                print(f"   ❌ Failed to delete {args.app_key}@{version}")
        
        print(f"\n📊 DELETION SUMMARY:")
        print(f"   Successfully deleted: {deleted_count}")
        print(f"   Failed to delete: {len(faulty_versions) - deleted_count}")
        
        if deleted_count == len(faulty_versions):
            print("   🎉 All faulty versions successfully deleted!")
            print("   💡 You can now try deleting the Docker images again")
        
        return 0 if deleted_count == len(faulty_versions) else 1

if __name__ == '__main__':
    sys.exit(main())
