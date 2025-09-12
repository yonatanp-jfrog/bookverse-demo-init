#!/bin/bash
set -euo pipefail

# BookVerse Monorepo Backup Script
# Creates comprehensive backups before monorepo split operations

BACKUP_BASE_DIR="$HOME/bookverse-backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="$BACKUP_BASE_DIR/bookverse-demo-backup-$TIMESTAMP"

echo "🛡️  Creating comprehensive BookVerse backup..."
echo "📁 Backup directory: $BACKUP_DIR"

# Create backup directory
mkdir -p "$BACKUP_DIR"

echo ""
echo "📋 Step 1: Creating full repository backup with git history..."
# Full git clone with all history
git clone --mirror "$(pwd)" "$BACKUP_DIR/bookverse-demo.git"
echo "✅ Git mirror backup created: $BACKUP_DIR/bookverse-demo.git"

echo ""
echo "📋 Step 2: Creating file system backup..."
# Create tar.gz backup of entire working directory
tar -czf "$BACKUP_DIR/bookverse-demo-files-$TIMESTAMP.tar.gz" \
    --exclude='.git' \
    --exclude='node_modules' \
    --exclude='*.pyc' \
    --exclude='__pycache__' \
    --exclude='.DS_Store' \
    .
echo "✅ File backup created: $BACKUP_DIR/bookverse-demo-files-$TIMESTAMP.tar.gz"

echo ""
echo "📋 Step 3: Creating individual service backups..."
for SERVICE_DIR in bookverse-*; do
    if [[ -d "$SERVICE_DIR" && "$SERVICE_DIR" != "bookverse-demo"* ]]; then
        echo "📦 Backing up $SERVICE_DIR..."
        tar -czf "$BACKUP_DIR/${SERVICE_DIR}-$TIMESTAMP.tar.gz" "$SERVICE_DIR"
    fi
done

echo ""
echo "📋 Step 4: Saving current git status and branch info..."
{
    echo "=== Git Status ==="
    git status
    echo ""
    echo "=== Current Branch ==="
    git branch -v
    echo ""
    echo "=== Remote URLs ==="
    git remote -v
    echo ""
    echo "=== Recent Commits ==="
    git log --oneline -10
    echo ""
    echo "=== Git Configuration ==="
    git config --list
} > "$BACKUP_DIR/git-info-$TIMESTAMP.txt"

echo ""
echo "📋 Step 5: Creating GitHub repository list..."
if command -v gh >/dev/null 2>&1; then
    {
        echo "=== Current GitHub Repositories ==="
        gh repo list yonatanp-jfrog --limit 100
        echo ""
        echo "=== Repository Details ==="
        for repo in bookverse-inventory bookverse-recommendations bookverse-checkout bookverse-platform bookverse-web bookverse-helm; do
            echo "--- $repo ---"
            gh repo view "yonatanp-jfrog/$repo" 2>/dev/null || echo "Repository does not exist"
            echo ""
        done
    } > "$BACKUP_DIR/github-repos-$TIMESTAMP.txt"
fi

echo ""
echo "📋 Step 6: Creating restore instructions..."
cat > "$BACKUP_DIR/RESTORE_INSTRUCTIONS.md" << 'EOF'
# BookVerse Backup Restore Instructions

This backup was created before monorepo split operations.

## What's Included

1. **Git Mirror**: `bookverse-demo.git` - Complete git repository with all history
2. **File Backup**: `bookverse-demo-files-*.tar.gz` - All files without git history
3. **Service Backups**: Individual service tar.gz files
4. **Git Info**: Current git status, branches, remotes, recent commits
5. **GitHub Info**: Current repository states (if gh CLI was available)

## How to Restore

### Option 1: Restore Full Repository
```bash
# Clone from the mirror backup
git clone bookverse-demo.git restored-bookverse-demo
cd restored-bookverse-demo
git remote set-url origin git@github.com:yonatanp-jfrog/bookverse-demo.git
```

### Option 2: Restore Files Only
```bash
# Extract files backup
tar -xzf bookverse-demo-files-*.tar.gz
# This gives you all files but no git history
```

### Option 3: Restore Individual Service
```bash
# Extract specific service
tar -xzf bookverse-inventory-*.tar.gz
```

## Emergency Contact

If you need help restoring, the backup contains:
- Complete git history in bookverse-demo.git
- All file contents in the tar.gz files
- Git configuration and status information

## Verification

To verify backup integrity:
```bash
# Check git mirror
git clone --bare bookverse-demo.git test-restore
cd test-restore && git log --oneline -5

# Check file backup
tar -tzf bookverse-demo-files-*.tar.gz | head -20
```
EOF

echo ""
echo "📋 Step 7: Creating backup verification..."
# Verify backups
echo "🔍 Verifying backups..."
if [[ -f "$BACKUP_DIR/bookverse-demo-files-$TIMESTAMP.tar.gz" ]]; then
    SIZE=$(du -h "$BACKUP_DIR/bookverse-demo-files-$TIMESTAMP.tar.gz" | cut -f1)
    echo "✅ File backup size: $SIZE"
else
    echo "❌ File backup not found!"
fi

if [[ -d "$BACKUP_DIR/bookverse-demo.git" ]]; then
    COMMIT_COUNT=$(git --git-dir="$BACKUP_DIR/bookverse-demo.git" rev-list --all --count)
    echo "✅ Git backup contains $COMMIT_COUNT commits"
else
    echo "❌ Git backup not found!"
fi

echo ""
echo "🎉 Backup Complete!"
echo "📁 Backup location: $BACKUP_DIR"
echo "📊 Backup contents:"
ls -lh "$BACKUP_DIR"

echo ""
echo "🛡️  Your data is safe! You can now proceed with monorepo operations."
echo "💡 To restore: See $BACKUP_DIR/RESTORE_INSTRUCTIONS.md"
