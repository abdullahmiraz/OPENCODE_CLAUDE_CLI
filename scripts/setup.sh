#!/usr/bin/env bash
# Guided setup — pauses and asks before each step.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CLAUDE_DIR="${HOME}/.claude"
PROXY_DIR="${HOME}/.config/routatic-proxy"
ENV_FILE="${REPO_ROOT}/.env"

pause() {
  echo ""
  read -rp "Press Enter to continue (or Ctrl+C to stop)... "
  echo ""
}

confirm() {
  local msg="$1"
  read -rp "${msg} [y/N] " ans
  [[ "${ans,,}" == "y" || "${ans,,}" == "yes" ]]
}

echo "=========================================="
echo "  OpenCode Go + Claude Code — guided setup"
echo "=========================================="
echo ""
echo "This script will guide you through 8 steps."
echo "It stops before each action so you can see what happens."
echo "Paths on your PC:"
echo "  Proxy config  -> ${PROXY_DIR}/config.json"
echo "  Claude config -> ${CLAUDE_DIR}/settings.json"
echo "  Templates from -> ${REPO_ROOT}/templates/"
pause

# --- Step 1 ---
echo "STEP 1/8 — OpenCode Go API key"
echo "  Get it from: https://opencode.ai -> Zen -> Go -> API key"
echo "  Saved to: ${ENV_FILE} (gitignored, never committed)"
if [[ -f "$ENV_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$ENV_FILE"
fi
if [[ -z "${OPENCODE_GO_API_KEY:-}" ]]; then
  read -rsp "  Paste your API key: " OPENCODE_GO_API_KEY
  echo ""
  [[ -n "$OPENCODE_GO_API_KEY" ]] || { echo "Key required."; exit 1; }
  echo "OPENCODE_GO_API_KEY=${OPENCODE_GO_API_KEY}" > "$ENV_FILE"
  chmod 600 "$ENV_FILE"
  echo "  Saved."
else
  echo "  Using key from existing .env"
fi
export ROUTATIC_PROXY_API_KEY="$OPENCODE_GO_API_KEY"
pause

# --- Step 2 ---
echo "STEP 2/8 — Install routatic-proxy"
if command -v routatic-proxy >/dev/null 2>&1; then
  echo "  Already installed: $(routatic-proxy --version 2>/dev/null || true)"
else
  echo "  Windows: uses Scoop (see README -> What is Scoop?)"
  echo "  Mac/Linux: uses Homebrew"
  if confirm "  Install routatic-proxy now?"; then
    if command -v scoop >/dev/null 2>&1; then
      scoop bucket add routatic https://github.com/routatic/scoop-bucket 2>/dev/null || true
      scoop install routatic-proxy
    elif command -v brew >/dev/null 2>&1; then
      brew tap routatic/tap && brew install routatic-proxy
    else
      echo "  Install Scoop/Homebrew first, or get binary from:"
      echo "  https://github.com/routatic/proxy/releases"
      exit 1
    fi
  else
    echo "  Skipped — install manually, then re-run this script."
    exit 1
  fi
fi
pause

# --- Step 3 ---
echo "STEP 3/8 — Install Claude Code CLI"
if command -v claude >/dev/null 2>&1; then
  echo "  Already installed."
else
  if confirm "  Run: npm install -g @anthropic-ai/claude-code ?"; then
    npm install -g @anthropic-ai/claude-code
  else
    echo "  Skipped — install manually with npm."
    exit 1
  fi
fi
pause

# --- Step 4 ---
echo "STEP 4/8 — Copy proxy config"
echo "  FROM: ${REPO_ROOT}/templates/routatic-proxy.config.json"
echo "  TO:   ${PROXY_DIR}/config.json"
if confirm "  Copy template and write your API key into config.json?"; then
  mkdir -p "$PROXY_DIR"
  cp "${REPO_ROOT}/templates/routatic-proxy.config.json" "${PROXY_DIR}/config.json"
  if command -v node >/dev/null 2>&1; then
    node -e "
      const fs=require('fs');
      const p='${PROXY_DIR}/config.json';
      let j=fs.readFileSync(p,'utf8');
      j=j.replace('\${ROUTATIC_PROXY_API_KEY}','${OPENCODE_GO_API_KEY}');
      fs.writeFileSync(p,j);
    "
  else
    echo "  Copied. Edit ${PROXY_DIR}/config.json and set api_key manually."
  fi
  echo "  Done."
else
  echo "  Skipped — copy the template yourself (see README Path A Step 4)."
fi
pause

# --- Step 5 ---
echo "STEP 5/8 — Claude Code settings"
echo "  FROM: ${REPO_ROOT}/templates/claude-settings.json"
echo "  TO:   ${CLAUDE_DIR}/settings.json"
SETTINGS="${CLAUDE_DIR}/settings.json"
TEMPLATE="${REPO_ROOT}/templates/claude-settings.json"
if confirm "  Copy or merge Claude settings?"; then
  mkdir -p "$CLAUDE_DIR"
  if [[ -f "$SETTINGS" ]]; then
    BACKUP="${SETTINGS}.backup.$(date +%s)"
    cp "$SETTINGS" "$BACKUP"
    echo "  Backed up to ${BACKUP}"
    node -e "
      const fs=require('fs');
      const cur=JSON.parse(fs.readFileSync('${SETTINGS}','utf8'));
      const tpl=JSON.parse(fs.readFileSync('${TEMPLATE}','utf8'));
      cur.env={...cur.env,...tpl.env};
      fs.writeFileSync('${SETTINGS}',JSON.stringify(cur,null,2)+'\n');
    "
  else
    cp "$TEMPLATE" "$SETTINGS"
  fi
  echo "  Done."
else
  echo "  Skipped — merge templates/claude-settings.json yourself."
fi
pause

# --- Step 6 ---
echo "STEP 6/8 — Start routatic-proxy"
if confirm "  Start proxy in background on http://127.0.0.1:3456 ?"; then
  routatic-proxy stop 2>/dev/null || true
  ROUTATIC_PROXY_API_KEY="$OPENCODE_GO_API_KEY" routatic-proxy serve -b
  sleep 2
  routatic-proxy status
else
  echo "  Skipped — start later with: routatic-proxy serve -b"
fi
pause

# --- Step 7 ---
echo "STEP 7/8 — Autostart on login (optional)"
if confirm "  Enable autostart?"; then
  routatic-proxy autostart enable 2>/dev/null || echo "  Not supported on this OS."
else
  echo "  Skipped."
fi
pause

# --- Step 8 ---
echo "STEP 8/8 — Verify (free checks only, no tokens)"
bash "${REPO_ROOT}/scripts/check.sh" || true
echo ""
echo "=========================================="
echo "  Setup complete. Run:  claude"
echo "  Re-check anytime:    bash scripts/check.sh"
echo "=========================================="
