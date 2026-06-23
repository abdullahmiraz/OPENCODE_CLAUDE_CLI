#!/usr/bin/env bash
# One-command setup: OpenCode Go + routatic-proxy + Claude Code CLI
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CLAUDE_DIR="${HOME}/.claude"
PROXY_DIR="${HOME}/.config/routatic-proxy"
ENV_FILE="${REPO_ROOT}/.env"

echo "==> OpenCode Go + Claude Code setup"
echo ""

# --- Step 1: API key ---
if [[ -f "$ENV_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$ENV_FILE"
fi

if [[ -z "${OPENCODE_GO_API_KEY:-}" ]]; then
  echo "Step 1: Enter your OpenCode Go API key"
  echo "  (from https://opencode.ai → Zen → Go → API key)"
  read -rsp "API key: " OPENCODE_GO_API_KEY
  echo ""
  if [[ -z "$OPENCODE_GO_API_KEY" ]]; then
    echo "Error: API key is required." >&2
    exit 1
  fi
  echo "OPENCODE_GO_API_KEY=${OPENCODE_GO_API_KEY}" > "$ENV_FILE"
  chmod 600 "$ENV_FILE"
  echo "  Saved to ${ENV_FILE} (gitignored)"
else
  echo "Step 1: API key found in .env"
fi
export ROUTATIC_PROXY_API_KEY="$OPENCODE_GO_API_KEY"
echo ""

# --- Step 2: Install routatic-proxy ---
echo "Step 2: Install routatic-proxy"
if command -v routatic-proxy >/dev/null 2>&1; then
  echo "  Already installed: $(routatic-proxy --version 2>/dev/null || true)"
elif command -v scoop >/dev/null 2>&1; then
  scoop bucket add routatic https://github.com/routatic/scoop-bucket 2>/dev/null || true
  scoop install routatic-proxy
elif command -v brew >/dev/null 2>&1; then
  brew tap routatic/tap && brew install routatic-proxy
else
  echo "  Install manually: https://github.com/routatic/proxy#quick-start"
  exit 1
fi
echo ""

# --- Step 3: Install Claude Code CLI ---
echo "Step 3: Install Claude Code CLI"
if command -v claude >/dev/null 2>&1; then
  echo "  Already installed"
else
  npm install -g @anthropic-ai/claude-code
fi
echo ""

# --- Step 4: Proxy config ---
echo "Step 4: Write routatic-proxy config"
mkdir -p "$PROXY_DIR"
cp "${REPO_ROOT}/templates/routatic-proxy.config.json" "${PROXY_DIR}/config.json"
echo "  -> ${PROXY_DIR}/config.json"
echo ""

# --- Step 5: Claude Code settings ---
echo "Step 5: Merge Claude Code settings"
mkdir -p "$CLAUDE_DIR"
SETTINGS="${CLAUDE_DIR}/settings.json"
TEMPLATE="${REPO_ROOT}/templates/claude-settings.json"

if [[ -f "$SETTINGS" ]]; then
  BACKUP="${SETTINGS}.backup.$(date +%s)"
  cp "$SETTINGS" "$BACKUP"
  echo "  Backed up existing settings to ${BACKUP}"
  if command -v node >/dev/null 2>&1; then
    node -e "
      const fs = require('fs');
      const cur = JSON.parse(fs.readFileSync('${SETTINGS}', 'utf8'));
      const tpl = JSON.parse(fs.readFileSync('${TEMPLATE}', 'utf8'));
      cur.env = { ...cur.env, ...tpl.env };
      fs.writeFileSync('${SETTINGS}', JSON.stringify(cur, null, 2) + '\n');
    "
  else
    cp "$TEMPLATE" "$SETTINGS"
    echo "  Warning: node not found; replaced settings.json entirely"
  fi
else
  cp "$TEMPLATE" "$SETTINGS"
fi
echo "  -> ${SETTINGS}"
echo ""

# --- Step 6: Start proxy ---
echo "Step 6: Start routatic-proxy"
if routatic-proxy status 2>/dev/null | grep -qi running; then
  routatic-proxy stop 2>/dev/null || true
fi
ROUTATIC_PROXY_API_KEY="$OPENCODE_GO_API_KEY" routatic-proxy serve -b
sleep 2
routatic-proxy status
echo ""

# --- Step 7: Enable autostart ---
echo "Step 7: Enable autostart on login"
routatic-proxy autostart enable 2>/dev/null || echo "  Skipped (not supported on this OS)"
echo ""

# --- Step 8: Verify ---
echo "Step 8: Verify"
RESULT=$(curl -sf -X POST http://127.0.0.1:3456/v1/messages \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer unused" \
  -H "anthropic-version: 2023-06-01" \
  -d '{"model":"deepseek-v4-flash","max_tokens":256,"messages":[{"role":"user","content":"Reply with exactly: ok"}]}' \
  2>&1) || { echo "  Proxy test failed. Check logs: ${PROXY_DIR}/routatic-proxy.log"; exit 1; }

if echo "$RESULT" | grep -q '"text"'; then
  echo "  Proxy OK"
else
  echo "  Unexpected response: ${RESULT}"
  exit 1
fi
echo ""

echo "Done. Run: claude"
echo "Logs:  ${PROXY_DIR}/routatic-proxy.log"
echo "Stop:  routatic-proxy stop"
