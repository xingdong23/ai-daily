#!/bin/bash
# AI Daily Site - Daily content generator
# Run by cron to search for new content and update the site

SITE_DIR="$HOME/ai-daily-site"
DATA_DIR="$SITE_DIR/data"
CONTENT_FILE="$DATA_DIR/content.json"
TODAY=$(date +%Y-%m-%d)
TIMESTAMP=$(date '+%Y-%m-%d %H:%M')
LOG_FILE="$HOME/.openclaw/workspace-ceo/memory/site-update.log"

echo "[$TIMESTAMP] Starting daily update..." >> "$LOG_FILE"

# Create a temp file with the update request for OpenClaw to process
# This script triggers OpenClaw to do the actual content generation
# because we need AI to search + summarize

# Write a trigger file that the heartbeat or cron agent will pick up
cat > "$SITE_DIR/.pending-update" << EOF
---
type: site-update
date: $TODAY
timestamp: $TIMESTAMP
action: search-and-update
sections:
  - daily
  - money
EOF

echo "[$TIMESTAMP] Trigger file created. Waiting for AI processing." >> "$LOG_FILE"
