#!/usr/bin/env python3
"""
Script to find AppTrust application versions containing faulty Docker images by checking releasables.
Uses parallel processing to speed up the search across multiple applications and versions.
"""

import os
import sys
import json
import requests
from typing import List, Dict, Optional, Tuple
import argparse
from urllib.parse import urljoin
from concurrent.futures import ThreadPoolExecutor, as_completed
import threading

class AppTrustScanner:
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
        self.lock = threading.Lock()

    def _log(self, message: str):
        if self.verbose:
            with self.lock:
                print(f"[DEBUG] {message}")

    def _make_request(self, method: str, endpoint: str, **kwargs) -> requests.Response:
        url = urljoin(self.base_url, endpoint)
        if self.verbose:
            with self.lock:
                print(f"[API] {method} {url}")
        
        response = self.session.request(method, url, **kwargs)
        
        if self.verbose:
            with self.lock:
                print(f"[API] Response: {response.status_code}")
                if response.status_code >= 400:
                    print(f"[API] Error: {response.text}")
        
        return response

    def list_applications(self) -> List[str]:
        """List all applications in the project."""
        endpoint = f"/apptrust/api/v1/applications"
        
        try:
            response = self._make_request('GET', endpoint, params={'project': self.project_key})
            if response.status_code == 200:
                data = response.json()
                # Handle both possible response formats
                if isinstance(data, list):
                    apps = data
                else:
                    apps = data.get('applications', [])
                return [app.get('application_key', '') for app in apps if isinstance(app, dict) and app.get('application_key')]
            else:
                print(f"❌ Failed to list applications: HTTP {response.status_code}")
                return []
        except Exception as e:
            print(f"❌ Error listing applications: {e}")
            return []

    def list_application_versions(self, app_key: str) -> List[Dict]:
        """List all versions for an application."""
        endpoint = f"/apptrust/api/v1/applications/{app_key}/versions"
        
        try:
            response = self._make_request('GET', endpoint)
            if response.status_code == 200:
                return response.json().get('versions', [])
            else:
                self._log(f"Failed to list versions for {app_key}: HTTP {response.status_code}")
                return []
        except Exception as e:
            self._log(f"Error listing versions for {app_key}: {e}")
            return []

    def get_version_releasables(self, app_key: str, version: str) -> Optional[List[Dict]]:
        """Get releasable content of a specific application version."""
        endpoint = f"/apptrust/api/v1/applications/{app_key}/versions/{version}/content"
        
        try:
            response = self._make_request('GET', endpoint, params={'include': 'releasables'})
            if response.status_code == 200:
                data = response.json()
                return data.get('releasables', [])
            else:
                self._log(f"Failed to get releasables for {app_key}@{version}: HTTP {response.status_code}")
                return None
        except Exception as e:
            self._log(f"Error getting releasables for {app_key}@{version}: {e}")
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

def contains_faulty_version(releasables: List[Dict], target_version: str = "180-1") -> Tuple[bool, List[str]]:
    """Check if releasables contain the faulty version and return matching releasable names."""
    if not releasables:
        return False, []
    
    faulty_releasables = []
    for releasable in releasables:
        version = releasable.get('version', '')
        name = releasable.get('name', '')
        package_type = releasable.get('package_type', '')
        
        # Check for exact match of the faulty version
        if version == target_version and package_type == 'docker':
            faulty_releasables.append(f"{name}:{version}")
    
    return len(faulty_releasables) > 0, faulty_releasables

def scan_version(scanner: AppTrustScanner, app_key: str, version_info: Dict, target_version: str) -> Optional[Dict]:
    """Scan a single version for faulty releasables."""
    version = version_info.get('version', '')
    status = version_info.get('status', '')
    created = version_info.get('created', '')
    
    scanner._log(f"Scanning {app_key}@{version}")
    
    releasables = scanner.get_version_releasables(app_key, version)
    if releasables is None:
        return None
    
    has_faulty, faulty_list = contains_faulty_version(releasables, target_version)
    
    if has_faulty:
        return {
            'app_key': app_key,
            'version': version,
            'status': status,
            'created': created,
            'faulty_releasables': faulty_list,
            'total_releasables': len(releasables)
        }
    
    return None

def scan_application(scanner: AppTrustScanner, app_key: str, target_version: str, max_workers: int = 5) -> List[Dict]:
    """Scan all versions of an application for faulty releasables."""
    print(f"📦 Scanning application: {app_key}")
    
    versions = scanner.list_application_versions(app_key)
    if not versions:
        print(f"   No versions found for {app_key}")
        return []
    
    print(f"   Found {len(versions)} versions")
    
    faulty_versions = []
    
    # Use ThreadPoolExecutor for parallel version scanning
    with ThreadPoolExecutor(max_workers=max_workers) as executor:
        # Submit all version scan tasks
        future_to_version = {
            executor.submit(scan_version, scanner, app_key, version_info, target_version): version_info
            for version_info in versions
        }
        
        # Collect results as they complete
        for future in as_completed(future_to_version):
            version_info = future_to_version[future]
            try:
                result = future.result()
                if result:
                    faulty_versions.append(result)
                    print(f"   🚨 FOUND faulty version: {result['version']} with {len(result['faulty_releasables'])} faulty releasables")
            except Exception as e:
                print(f"   ❌ Error scanning version {version_info.get('version', 'unknown')}: {e}")
    
    return faulty_versions

def main():
    parser = argparse.ArgumentParser(description='Find AppTrust versions with faulty Docker image versions')
    parser.add_argument('--jfrog-url', required=True, help='JFrog base URL')
    parser.add_argument('--jfrog-token', required=True, help='JFrog access token')
    parser.add_argument('--project-key', default='bookverse', help='Project key (default: bookverse)')
    parser.add_argument('--target-version', default='180-1', help='Faulty version to find (default: 180-1)')
    parser.add_argument('--apps', help='Comma-separated list of applications to scan (default: all)')
    parser.add_argument('--dry-run', action='store_true', help='Show what would be deleted without actually deleting')
    parser.add_argument('--verbose', action='store_true', help='Enable verbose logging')
    parser.add_argument('--max-workers', type=int, default=5, help='Max parallel workers per application (default: 5)')
    parser.add_argument('--app-workers', type=int, default=3, help='Max parallel applications to scan (default: 3)')
    
    args = parser.parse_args()
    
    # Initialize scanner
    scanner = AppTrustScanner(args.jfrog_url, args.jfrog_token, args.project_key, args.verbose)
    
    print("🔍 Scanning AppTrust applications for faulty Docker image versions...")
    print(f"   JFrog URL: {args.jfrog_url}")
    print(f"   Project: {args.project_key}")
    print(f"   Target version: {args.target_version}")
    print(f"   Mode: {'DRY RUN' if args.dry_run else 'DELETE'}")
    print(f"   Parallel workers: {args.max_workers} per app, {args.app_workers} apps")
    print()
    
    # Get applications to scan
    if args.apps:
        applications = [app.strip() for app in args.apps.split(',') if app.strip()]
    else:
        applications = scanner.list_applications()
    
    if not applications:
        print("❌ No applications found to scan")
        return 1
    
    print(f"📋 Applications to scan: {', '.join(applications)}")
    print()
    
    all_faulty_versions = []
    
    # Use ThreadPoolExecutor for parallel application scanning
    with ThreadPoolExecutor(max_workers=args.app_workers) as executor:
        # Submit all application scan tasks
        future_to_app = {
            executor.submit(scan_application, scanner, app_key, args.target_version, args.max_workers): app_key
            for app_key in applications
        }
        
        # Collect results as they complete
        for future in as_completed(future_to_app):
            app_key = future_to_app[future]
            try:
                faulty_versions = future.result()
                all_faulty_versions.extend(faulty_versions)
            except Exception as e:
                print(f"❌ Error scanning application {app_key}: {e}")
    
    print()
    print("=" * 60)
    print("📊 SUMMARY")
    print(f"   Applications scanned: {len(applications)}")
    print(f"   Total faulty versions found: {len(all_faulty_versions)}")
    
    if not all_faulty_versions:
        print("   🎉 No versions contain the faulty Docker image version!")
        return 0
    
    # Show details of faulty versions
    print(f"\n🚨 FAULTY VERSIONS FOUND:")
    for fv in all_faulty_versions:
        print(f"\n   Application: {fv['app_key']}")
        print(f"   Version: {fv['version']}")
        print(f"   Status: {fv['status']}")
        print(f"   Created: {fv['created']}")
        print(f"   Total releasables: {fv['total_releasables']}")
        print(f"   Faulty releasables: {', '.join(fv['faulty_releasables'])}")
    
    # Deletion logic
    if args.dry_run:
        print(f"\n🔍 DRY RUN: Would delete {len(all_faulty_versions)} faulty versions")
        for fv in all_faulty_versions:
            print(f"   Would delete: {fv['app_key']}@{fv['version']}")
    else:
        print(f"\n🗑️ DELETING {len(all_faulty_versions)} faulty versions...")
        deleted_count = 0
        
        for fv in all_faulty_versions:
            app_key = fv['app_key']
            version = fv['version']
            print(f"   Deleting {app_key}@{version}...")
            
            if scanner.delete_application_version(app_key, version):
                print(f"   ✅ Deleted {app_key}@{version}")
                deleted_count += 1
            else:
                print(f"   ❌ Failed to delete {app_key}@{version}")
        
        print(f"\n📊 DELETION SUMMARY:")
        print(f"   Successfully deleted: {deleted_count}")
        print(f"   Failed to delete: {len(all_faulty_versions) - deleted_count}")
        
        if deleted_count == len(all_faulty_versions):
            print("   🎉 All faulty versions successfully deleted!")
            print("   💡 You can now try deleting the Docker images again")
        
        return 0 if deleted_count == len(all_faulty_versions) else 1

if __name__ == '__main__':
    sys.exit(main())
