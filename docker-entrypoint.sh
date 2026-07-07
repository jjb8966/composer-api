#!/bin/sh
set -eu

if [ -f /app/package.json ]; then
  cd /app
else
  cd "$(dirname "$0")"
fi

cat > .dev.vars <<EOF
ENCRYPTION_KEY="${ENCRYPTION_KEY:?ENCRYPTION_KEY is required}"
CURSOR_BACKEND_BASE_URL="${CURSOR_BACKEND_BASE_URL:-}"
CURSOR_CHAT_ENDPOINT="${CURSOR_CHAT_ENDPOINT:-}"
CURSOR_SDK_BRIDGE_URL="${CURSOR_SDK_BRIDGE_URL:-}"
CURSOR_SDK_BRIDGE_TOKEN="${CURSOR_SDK_BRIDGE_TOKEN:-}"
CURSOR_SDK_BRIDGE_TIMEOUT_MS="${CURSOR_SDK_BRIDGE_TIMEOUT_MS:-180000}"
CURSOR_SDK_BRIDGE_RUN_TIMEOUT_MS="${CURSOR_SDK_BRIDGE_RUN_TIMEOUT_MS:-180000}"
CURSOR_CLIENT_VERSION="${CURSOR_CLIENT_VERSION:-2.6.22}"
CURSOR_SDK_CLIENT_VERSION="${CURSOR_SDK_CLIENT_VERSION:-sdk-1.0.13}"
WAITLIST_API_TOKEN="${WAITLIST_API_TOKEN:-standard-agents-waitlist-token}"
EOF

if [ ! -f wrangler.jsonc.upstream ]; then
  cp wrangler.jsonc wrangler.jsonc.upstream
fi
cp wrangler.docker.jsonc wrangler.jsonc

exec npm run dev -- --host 0.0.0.0 --port "${PORT:-8788}" --strictPort
