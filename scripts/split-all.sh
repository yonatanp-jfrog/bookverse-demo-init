#!/bin/bash
set -euo pipefail


SERVICES=(
    "bookverse-checkout"
    "bookverse-platform"
    "bookverse-web"
    "bookverse-helm"
)

echo "🚀 Creating remaining BookVerse service repositories"
echo ""

for SERVICE in "${SERVICES[@]}"; do
    echo "🔄 Processing: $SERVICE"
    ./scripts/simple-split.sh "$SERVICE"
    echo ""
done

echo "🎉 All repositories created successfully!"
echo ""
echo "📋 Summary:"
echo "✅ bookverse-inventory: https://github.com/yonatanp-jfrog/bookverse-inventory"
echo "✅ bookverse-recommendations: https://github.com/yonatanp-jfrog/bookverse-recommendations"  
echo "✅ bookverse-checkout: https://github.com/yonatanp-jfrog/bookverse-checkout"
echo "✅ bookverse-platform: https://github.com/yonatanp-jfrog/bookverse-platform"
echo "✅ bookverse-web: https://github.com/yonatanp-jfrog/bookverse-web"
echo "✅ bookverse-helm: https://github.com/yonatanp-jfrog/bookverse-helm"
