
import os
import sys
import json
import re
import requests
from typing import List, Dict, Tuple, Optional
import argparse
from urllib.parse import urljoin

SERVICES = ['inventory', 'recommendations', 'checkout', 'platform', 'web']

SEMVER_PATTERN = re.compile(r'^v?\d+\.\d+\.\d+(?:-[a-zA-Z0-9]+(?:\.[a-zA-Z0-9]+)*)?(?:\+[a-zA-Z0-9]+(?:\.[a-zA-Z0-9]+)*)?$')

BUILD_NUMBER_PATTERN = re.compile(r'^\d+-\d+$')

class JFrogClient:
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

    def get_docker_repositories(self) -> List[str]:
        repos = []
        for service in SERVICES:
            for env in ['nonprod', 'prod']:
                repo_name = f"{self.project_key}-{service}-internal-docker-{env}-local"
                repos.append(repo_name)
        return repos

    def list_docker_tags(self, repository: str, image_name: str) -> List[str]:
        endpoint = f"/artifactory/api/docker/{repository}/v2/{image_name}/tags/list"
        
        try:
            response = self._make_request('GET', endpoint)
            if response.status_code == 200:
                data = response.json()
                return data.get('tags', [])
            elif response.status_code == 404:
                self._log(f"Image {image_name} not found in repository {repository}")
                return []
            else:
                print(f"❌ Failed to list tags for {repository}/{image_name}: HTTP {response.status_code}")
                return []
        except Exception as e:
            print(f"❌ Error listing tags for {repository}/{image_name}: {e}")
            return []

    def delete_docker_image(self, repository: str, image_name: str, tag: str) -> bool:
        endpoint = f"/artifactory/{repository}/{image_name}/{tag}"
        
        try:
            response = self._make_request('DELETE', endpoint)
            if response.status_code in [200, 204]:
                return True
            else:
                print(f"❌ Failed to delete {repository}/{image_name}:{tag}: HTTP {response.status_code}")
                print(f"   Response: {response.text}")
                return False
        except Exception as e:
            print(f"❌ Error deleting {repository}/{image_name}:{tag}: {e}")
            return False

    def get_image_info(self, repository: str, image_name: str, tag: str) -> Optional[Dict]:
        endpoint = f"/artifactory/api/storage/{repository}/{image_name}/{tag}"
        
        try:
            response = self._make_request('GET', endpoint)
            if response.status_code == 200:
                return response.json()
            else:
                return None
        except Exception as e:
            self._log(f"Error getting image info for {repository}/{image_name}:{tag}: {e}")
            return None

def is_semver(tag: str) -> bool:
    return bool(SEMVER_PATTERN.match(tag))

def is_build_number(tag: str) -> bool:
    return bool(BUILD_NUMBER_PATTERN.match(tag))

def analyze_tags(tags: List[str]) -> Tuple[List[str], List[str], List[str]]:
    semver_tags = []
    build_number_tags = []
    other_tags = []
    
    for tag in tags:
        if is_semver(tag):
            semver_tags.append(tag)
        elif is_build_number(tag):
            build_number_tags.append(tag)
        else:
            other_tags.append(tag)
    
    return semver_tags, build_number_tags, other_tags

def main():
    parser = argparse.ArgumentParser(description='Cleanup faulty non-semver Docker images from BookVerse repositories')
    parser.add_argument('--jfrog-url', required=True, help='JFrog base URL')
    parser.add_argument('--jfrog-token', required=True, help='JFrog access token')
    parser.add_argument('--project-key', default='bookverse', help='Project key (default: bookverse)')
    parser.add_argument('--dry-run', action='store_true', help='Show what would be deleted without actually deleting')
    parser.add_argument('--verbose', action='store_true', help='Enable verbose logging')
    parser.add_argument('--target-tag', help='Specific tag to delete (e.g., "180-1")')
    parser.add_argument('--service', choices=SERVICES, help='Target specific service only')
    
    args = parser.parse_args()
    
    client = JFrogClient(args.jfrog_url, args.jfrog_token, args.project_key, args.verbose)
    
    print("🔍 Scanning BookVerse Docker repositories for faulty non-semver images...")
    print(f"   JFrog URL: {args.jfrog_url}")
    print(f"   Project: {args.project_key}")
    print(f"   Mode: {'DRY RUN' if args.dry_run else 'DELETE'}")
    print()
    
    services_to_scan = [args.service] if args.service else SERVICES
    total_faulty = 0
    total_deleted = 0
    
    for service in services_to_scan:
        print(f"📦 Scanning service: {service}")
        
        for env in ['nonprod', 'prod']:
            repo_name = f"{args.project_key}-{service}-internal-docker-{env}-local"
            print(f"   Repository: {repo_name}")
            
            image_names = [service]
            if service == 'checkout':
                image_names.extend(['checkout-worker', 'checkout-migrations'])
            
            for image_name in image_names:
                print(f"      Image: {image_name}")
                
                tags = client.list_docker_tags(repo_name, image_name)
                if not tags:
                    print(f"         No tags found")
                    continue
                
                semver_tags, build_number_tags, other_tags = analyze_tags(tags)
                
                print(f"         Total tags: {len(tags)}")
                print(f"         Semver tags: {len(semver_tags)}")
                print(f"         Build number tags: {len(build_number_tags)} ⚠️")
                print(f"         Other tags: {len(other_tags)}")
                
                if args.target_tag:
                    if args.target_tag in tags:
                        if is_build_number(args.target_tag) or not is_semver(args.target_tag):
                            print(f"         🎯 Target tag '{args.target_tag}' found - marking for deletion")
                            build_number_tags = [args.target_tag]
                        else:
                            print(f"         ✅ Target tag '{args.target_tag}' is valid semver - skipping")
                            build_number_tags = []
                    else:
                        print(f"         ❌ Target tag '{args.target_tag}' not found")
                        build_number_tags = []
                
                if build_number_tags:
                    print(f"         🚨 Found {len(build_number_tags)} faulty tags:")
                    for tag in build_number_tags:
                        total_faulty += 1
                        
                        info = client.get_image_info(repo_name, image_name, tag)
                        created = info.get('created', 'unknown') if info else 'unknown'
                        size = info.get('size', 'unknown') if info else 'unknown'
                        
                        print(f"            - {tag} (created: {created}, size: {size})")
                        
                        if not args.dry_run:
                            if client.delete_docker_image(repo_name, image_name, tag):
                                print(f"            ✅ Deleted {repo_name}/{image_name}:{tag}")
                                total_deleted += 1
                            else:
                                print(f"            ❌ Failed to delete {repo_name}/{image_name}:{tag}")
                        else:
                            print(f"            🔍 Would delete {repo_name}/{image_name}:{tag}")
                
                if semver_tags:
                    print(f"         ✅ Valid semver tags (showing first 3): {semver_tags[:3]}")
                
                print()
    
    print("=" * 60)
    print("📊 SUMMARY")
    print(f"   Total faulty images found: {total_faulty}")
    if args.dry_run:
        print(f"   Would delete: {total_faulty} images")
        print("   Run without --dry-run to actually delete these images")
    else:
        print(f"   Successfully deleted: {total_deleted}")
        print(f"   Failed to delete: {total_faulty - total_deleted}")
    
    if total_faulty == 0:
        print("   🎉 No faulty non-semver Docker images found!")
    elif not args.dry_run and total_deleted == total_faulty:
        print("   🎉 All faulty images successfully cleaned up!")
    
    return 0 if total_faulty == 0 or (not args.dry_run and total_deleted == total_faulty) else 1

if __name__ == '__main__':
    sys.exit(main())
