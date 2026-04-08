#!/bin/bash
# AI Daily Site - Auto Update Script
# Run by cron or manually to update the site content
# Usage: bash update-site.sh

set -e

SITE_DIR="$HOME/ai-daily-site"
DATA_DIR="$SITE_DIR/data"
CONTENT_FILE="$DATA_DIR/content.json"
KNOWLEDGE_DIR="$HOME/knowledge-base/raw"
TODAY=$(date +%Y-%m-%d)
TIMESTAMP=$(date '+%Y-%m-%d %H:%M')

echo "🔄 Updating AI Daily Site - $TIMESTAMP"

# Ensure git repo exists
cd "$SITE_DIR"
if [ ! -d ".git" ]; then
    echo "📦 Initializing git repo..."
    git init
    git add -A
    git commit -m "Initial commit"
fi

# Check if there are changes
if git diff --quiet 2>/dev/null && git diff --cached --quiet 2>/dev/null; then
    echo "✅ No changes to publish"
    exit 0
fi

# Commit and push
git add -A
git commit -m "🔄 Auto update - $TIMESTAMP" || true

# Push if remote is set
if git remote | grep -q origin; then
    git push origin main 2>/dev/null || git push origin master 2>/dev/null || echo "⚠️ Push failed, check remote"
else
    echo "ℹ️ No remote set. Set one with: cd ~/ai-daily-site && git remote add origin <url>"
fi

echo "✅ Site updated at $TIMESTAMP"
