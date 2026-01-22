#!/bin/bash

# SuperClaude Telegram Notification Hook
# Used by Claude to send notifications to Telegram

# Load environment variables
if [ -f ~/.superclaude/.env ]; then
    export $(cat ~/.superclaude/.env | grep -v '^#' | xargs)
fi

# Get parameters
EVENT_TYPE="${1:-notification}"
MESSAGE="${2:-Claude needs your attention}"

# Configuration
TELEGRAM_USER_ID="${TELEGRAM_USER_ID:-}"
API_URL="${API_ROUTER_URL:-http://localhost:3850}"

# Check if user ID is set
if [ -z "$TELEGRAM_USER_ID" ]; then
    echo "Warning: TELEGRAM_USER_ID not set" >&2
    exit 0  # Exit gracefully to not break Claude
fi

# Send notification
curl -X POST "$API_URL/api/notify" \
  -H "Content-Type: application/json" \
  -d "{
    \"userId\": \"$TELEGRAM_USER_ID\",
    \"event\": \"$EVENT_TYPE\",
    \"message\": \"$MESSAGE\",
    \"timestamp\": \"$(date -Iseconds)\"
  }" 2>/dev/null || true

# Always exit successfully to not interrupt Claude
exit 0