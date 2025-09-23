#!/usr/bin/env bash


set -e

source "$(dirname "$0")/config.sh"

echo ""
echo "🚀 Pre-populating dependencies for BookVerse platform"
echo "🔧 Project: $PROJECT_KEY"
echo "🔧 JFrog URL: $JFROG_URL"
echo ""

aql_query() {
    local query="$1"
    curl -sS -L \
        -H "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
        -H "Content-Type: text/plain" \
        -X POST \
        --data "$query" \
        "${JFROG_URL%/}/artifactory/api/search/aql" 2>/dev/null || true
}

is_python_package_cached() {
    local package="$1"
    local version="$2"

    if [[ -z "$version" || "$version" == "latest" ]]; then
        return 1
    fi

    local pkg_lower
    pkg_lower=$(echo "$package" | tr '[:upper:]' '[:lower:]')

    local aql_wheel
    aql_wheel=$(cat <<EOF
items.find({
  "\$or": [
    {"repo": "${PROJECT_KEY}-pypi-cache-local"},
    {"repo": "${PROJECT_KEY}-pypi-remote"}
  ],
  "\$and": [
    {"name": {"\$match": "*${pkg_lower}*-${version}*.whl"}},
    {"type": "file"}
  ]
}).include("name","repo","path").limit(1)
EOF
)

    local res
    res=$(aql_query "$aql_wheel")
    if echo "$res" | jq -e '.results | length > 0' >/dev/null 2>&1; then
        return 0
    fi

    local aql_sdist
    aql_sdist=$(cat <<EOF
items.find({
  "\$or": [
    {"repo": "${PROJECT_KEY}-pypi-cache-local"},
    {"repo": "${PROJECT_KEY}-pypi-remote"}
  ],
  "\$and": [
    {"name": {"\$match": "*${pkg_lower}*-${version}.tar.gz"}},
    {"type": "file"}
  ]
}).include("name","repo","path").limit(1)
EOF
)

    res=$(aql_query "$aql_sdist")
    echo "$res" | jq -e '.results | length > 0' >/dev/null 2>&1
}

is_npm_package_cached() {
    local package="$1"
    local version="$2"

    if [[ -z "$version" || "$version" == "latest" ]]; then
        return 1
    fi

    local base
    base="${package}"
    local tar
    tar="${base}-${version}.tgz"

    local aql
    aql=$(cat <<EOF
items.find({
  "\$or": [
    {"repo": "${PROJECT_KEY}-npm-cache-local"},
    {"repo": "${PROJECT_KEY}-npm-remote"}
  ],
  "name": {"\$match": "${tar}"},
  "type": "file"
}).include("name","repo","path").limit(1)
EOF
)

    local res
    res=$(aql_query "$aql")
    echo "$res" | jq -e '.results | length > 0' >/dev/null 2>&1
}

cache_python_package() {
    local package="$1"
    local version="${2:-latest}"
    
    echo "📦 Caching Python package: $package${version:+ ($version)}"
    
    if is_python_package_cached "$package" "$version"; then
        echo "⏭️  Already present in cache. Skipping $package${version:+ ($version)}"
        return 0
    fi
    
    if [[ "$version" == "latest" ]]; then
        pip download "$package" --no-deps > /dev/null 2>&1 || echo "⚠️ Warning: Could not cache $package"
    else
        pip download "$package==$version" --no-deps > /dev/null 2>&1 || echo "⚠️ Warning: Could not cache $package==$version"
    fi
    rm -f *.whl *.tar.gz
}

cache_npm_package() {
    local package="$1"
    local version="${2:-latest}"
    
    echo "📦 Caching npm package: $package${version:+ ($version)}"
    
    if is_npm_package_cached "$package" "$version"; then
        echo "⏭️  Already present in cache. Skipping $package${version:+ ($version)}"
        return 0
    fi
    
    if [[ "$version" == "latest" ]]; then
        npm pack "$package" > /dev/null 2>&1 || echo "⚠️ Warning: Could not cache $package"
    else
        npm pack "$package@$version" > /dev/null 2>&1 || echo "⚠️ Warning: Could not cache $package@$version"
    fi
    
    rm -f *.tgz
}

cache_docker_image() {
    local image="$1"
    local tag="${2:-latest}"
    
    echo "🐳 Caching Docker image: $image:$tag"
    
    local docker_registry_host=$(echo "$JFROG_URL" | sed 's|https://||' | sed 's|http://||')
    local virtual_repo_path="${docker_registry_host}/${PROJECT_KEY}-dockerhub-virtual"
    local cache_repo_key="${PROJECT_KEY}-dockerhub-cache-local"
    
    local image_path="$image"
    if [[ "$image" != */* ]]; then
        image_path="library/$image"
    fi
    
    local base_api_cache="${JFROG_URL%/}/artifactory/api/docker/${cache_repo_key}/v2"
    local manifest_url_cache="$base_api_cache/${image_path}/manifests/$tag"
    local head_code
    head_code=$(curl -sS -L -o /dev/null -w "%{http_code}" \
        -H "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
        -H "Accept: application/vnd.docker.distribution.manifest.v2+json, application/vnd.oci.image.manifest.v1+json" \
        "$manifest_url_cache" 2>/dev/null || echo 000)
    if [[ "$head_code" == "200" ]]; then
        echo "⏭️  Docker image already cached locally: $image:$tag — skipping"
        return 0
    fi
    
    # Try optimal JFrog CLI method first (for newer servers), fall back to regular docker pull (for older servers)
    if [[ "$USE_JF_DOCKER" == "true" ]]; then
        # First attempt: Use JFrog CLI (optimal for newer Artifactory versions)
        local jf_attempt
        for jf_attempt in 1 2; do
            if jf docker pull "${virtual_repo_path}/${image_path}:$tag" 2>/dev/null; then
                return 0
            fi
            if [[ "$image_path" == library/* ]]; then
                if jf docker pull "${virtual_repo_path}/${image}:$tag" 2>/dev/null; then
                    return 0
                fi
            fi
            sleep $jf_attempt
        done
        
        # Fallback: Use regular docker pull (compatibility for older Artifactory versions)
        echo "ℹ️ JFrog CLI docker pull failed, falling back to regular docker pull for older server compatibility"
    fi
    
    # Regular docker pull approach (fallback or primary for older servers)
    local attempt
    for attempt in 1 2 3; do
        if docker pull "${virtual_repo_path}/${image_path}:$tag" 2>/dev/null; then
            return 0
        fi
        if [[ "$image_path" == library/* ]]; then
            if docker pull "${virtual_repo_path}/${image}:$tag" 2>/dev/null; then
                return 0
            fi
        fi
        sleep $((attempt * 2))
    done
    echo "⚠️ docker pull failed for $image:$tag via ${virtual_repo_path}; attempting API prefetch"
    # Record warning for job summary detection (not a hard error since API prefetch works)
    echo "Docker pull failed for $image:$tag - fell back to API prefetch" >> /tmp/setup_warnings.log 2>/dev/null || true

    local base_api="${JFROG_URL%/}/artifactory/api/docker/${PROJECT_KEY}-dockerhub-virtual/v2"
    local manifest_url="$base_api/${image_path}/manifests/$tag"
    local mf=$(mktemp)
    local code
    code=$(curl -sS -L -o "$mf" -w "%{http_code}" \
        -H "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
        -H "Accept: application/vnd.docker.distribution.manifest.v2+json, application/vnd.oci.image.manifest.v1+json" \
        "$manifest_url" 2>/dev/null || echo 000)
    if [[ "$code" -ge 200 && "$code" -lt 300 ]]; then
        local config_digest
        config_digest=$(jq -r '.config.digest // empty' "$mf" 2>/dev/null || echo "")
        if [[ -n "$config_digest" ]]; then
            curl -sS -L -o /dev/null -w "%{http_code}" \
                -H "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
                "$base_api/${image_path}/blobs/${config_digest}" >/dev/null 2>&1 || true
        fi
        local digests
        digests=$(jq -r '.layers[]?.digest // empty' "$mf" 2>/dev/null || echo "")
        if [[ -n "$digests" ]]; then
            while IFS= read -r d; do
                [[ -z "$d" ]] && continue
                curl -sS -L -o /dev/null -w "%{http_code}" \
                    -H "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
                    "$base_api/${image_path}/blobs/${d}" >/dev/null 2>&1 || true
            done <<< "$digests"
        fi
        rm -f "$mf"
        echo "✅ Prefetched $image:$tag via API"
        return 0
    else
        echo "⚠️ Manifest prefetch failed for $image:$tag (HTTP $code)"
        echo "⚠️ Warning: Could not cache Docker image $image:$tag"
        rm -f "$mf"
    fi
}

echo "=== Configuring JFrog CLI for dependency management ==="
# Configure JFrog CLI server for authenticated operations
jf c add bookverse-admin --url="${JFROG_URL}" --access-token="${JFROG_ADMIN_TOKEN}" --interactive=false --overwrite
jf c use bookverse-admin

# Verify authentication before proceeding
auth_test_code=$(curl -s -H "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" -X GET "${JFROG_URL%/}/artifactory/api/system/ping" --write-out "%{http_code}" --output /dev/null)
if [ "$auth_test_code" -eq 200 ]; then
    echo "✅ JFrog CLI authentication verified"
else
    echo "❌ JFrog CLI authentication failed (HTTP $auth_test_code)"
    echo "⚠️ Falling back to API-only operations"
    export USE_JF_DOCKER="false"
fi

echo "🔐 Configuring secure Docker authentication..."

DOCKER_REG_HOST=$(echo "$JFROG_URL" | sed 's|https://||' | sed 's|http://||')
VIRTUAL_REPO_HOST="${DOCKER_REG_HOST}/${PROJECT_KEY}-dockerhub-virtual"

if command -v jf >/dev/null 2>&1; then
  echo "Configuring authentication for Docker virtual repository..."
  
  # Use the already-verified authentication status from above
  if [[ "$USE_JF_DOCKER" != "false" ]]; then
    echo "✅ Using JFrog CLI for secure Docker operations"
    echo "ℹ️ Configuring Docker authentication for JFrog registry..."
    
    # Get username from JWT token for Docker login
    jwt_payload=$(echo "${JFROG_ADMIN_TOKEN}" | cut -d'.' -f2)
    case $((${#jwt_payload} % 4)) in
      2) jwt_payload="${jwt_payload}==" ;;
      3) jwt_payload="${jwt_payload}=" ;;
    esac
    username=$(echo "${jwt_payload}" | base64 -d 2>/dev/null | jq -r '.sub' 2>/dev/null | cut -d'/' -f3 2>/dev/null || echo "admin")
    
    # Configure Docker authentication to JFrog registry
    if echo "${JFROG_ADMIN_TOKEN}" | docker login "${DOCKER_REG_HOST}" --username "${username}" --password-stdin >/dev/null 2>&1; then
      echo "✅ Docker authentication configured for ${DOCKER_REG_HOST}"
      export USE_JF_DOCKER="true"
    else
      echo "⚠️ Docker authentication failed, falling back to API operations"
      export USE_JF_DOCKER="false"
    fi
    
  else
    echo "❌ JFrog CLI authentication not available"
    echo "❌ Docker image caching will be limited to API operations"
    export USE_JF_DOCKER="false"
  fi
else
  echo "❌ JFrog CLI not available - Docker image caching will be skipped"
  export USE_JF_DOCKER="false"
fi

echo ""
echo "=== Pre-populating Python dependencies ==="

echo "📦 Downloading and uploading Python packages to local repository..."

TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

cd "$TEMP_DIR"

PACKAGES=(
    "fastapi==0.111.0"
    "uvicorn==0.30.0"
    "requests==2.31.0"
    "pytest==8.3.2"
    "pytest-cov==4.0.0"
    "httpx==0.27.0"
    "pydantic==2.11.9"
    "python-multipart==0.0.20"
    "python-dotenv==1.1.1"
    "SQLAlchemy"
    "starlette==0.37.2"
    "typing-extensions==4.15.0"
    "click"
    "h11"
    "anyio"
    "sniffio"
    "idna"
    "certifi"
    "charset-normalizer"
    "urllib3"
    "pluggy"
    "iniconfig"
    "packaging"
    "httpcore"
)

echo "📥 Downloading packages with dependencies..."
pip3 download "${PACKAGES[@]}" || echo "⚠️ Some downloads may have failed"

echo "📥 Downloading platform-independent wheels..."
pip3 download --platform any --only-binary=:all: \
  charset-normalizer urllib3 coverage || echo "⚠️ Some platform-independent downloads failed"

echo "📤 Uploading packages to JFrog local repository..."
for file in *.whl *.tar.gz; do
    if [[ -f "$file" ]]; then
        echo "  📤 Uploading: $file"
        curl -s -H "Authorization: Bearer ${JFROG_ADMIN_TOKEN}" \
             -X PUT \
             -T "$file" \
             "${JFROG_URL}/artifactory/${PROJECT_KEY}-pypi-cache-local/$file" \
             > /dev/null && echo "    ✅ Uploaded successfully" || echo "    ⚠️ Upload failed or already exists"
    fi
done

cd - > /dev/null

echo "✅ Python dependencies populated in local repository"

echo "📝 Note: Also attempting legacy caching approach for compatibility..."
jf pipc --repo-resolve "${PROJECT_KEY}-pypi-virtual"

cache_python_package "pip" "24.2"

cache_python_package "pytest" "8.3.2"
cache_python_package "pytest-cov" "4.0.0"
cache_python_package "httpx" "0.27.0"

cache_python_package "fastapi" "0.111.0"
cache_python_package "uvicorn" "0.30.0"
cache_python_package "pydantic" "2.11.9"
cache_python_package "pydantic" "2.5.0"
cache_python_package "sqlalchemy" "2.0.23"
cache_python_package "python-multipart" "0.0.20"
cache_python_package "python-dotenv" "1.1.1"

cache_python_package "safety" "3.2.7"

cache_python_package "black" "23.9.1"
cache_python_package "isort" "5.12.0"
cache_python_package "mypy" "1.5.1"

echo ""
echo "=== Pre-populating npm dependencies ==="

jf npmc --repo-resolve "${PROJECT_KEY}-npm-virtual"

cache_npm_package "npm" "10.8.2"
cache_npm_package "yarn" "1.22.22"

cache_npm_package "vite" "5.4.1"
cache_npm_package "typescript" "5.5.4"
cache_npm_package "@vitejs/plugin-react" "4.3.1"

cache_npm_package "react" "18.3.1"
cache_npm_package "react-dom" "18.3.1"
cache_npm_package "@types/react" "18.3.3"
cache_npm_package "@types/react-dom" "18.3.0"

cache_npm_package "vitest" "2.0.5"
cache_npm_package "jsdom" "25.0.0"

cache_npm_package "audit-ci" "7.1.0"

echo ""
echo "=== Pre-populating Docker base images ==="

cache_docker_image "python" "3.11-slim"
cache_docker_image "python" "3.11-alpine"

cache_docker_image "node" "20-alpine"
cache_docker_image "node" "20-slim"

cache_docker_image "nginx" "1.25-alpine"

cache_docker_image "alpine" "3.18"
cache_docker_image "ubuntu" "22.04"

echo ""
echo "✅ Dependency pre-population completed successfully!"
echo ""
echo "📋 Cached dependencies:"
echo "   🐍 Python: Core tools, FastAPI, testing, security, code quality"
echo "   📦 npm: Build tools, React, TypeScript, testing, security"
echo "   🐳 Docker: Base images for Python, Node.js, nginx, CI tools"
echo ""
echo "🔧 All services can now use dependencies from Artifactory repositories"
echo ""