#!/usr/bin/env bash
# Safe local checks only — no OpenCode API calls, no tokens spent.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROXY_CONFIG="${HOME}/.config/routatic-proxy/config.json"
CLAUDE_SETTINGS="${HOME}/.claude/settings.json"
PASS=0
FAIL=0

ok()   { echo "  OK   $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL $1"; FAIL=$((FAIL + 1)); }

echo "==> Local checks (no API / no tokens)"
echo ""

# 1. Repo templates exist and are valid routatic-proxy config
echo "[1] Repo templates"
TMPDIR_CHECK="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_CHECK"' EXIT
if [[ -f "${REPO_ROOT}/templates/routatic-proxy.config.json" && -f "${REPO_ROOT}/templates/claude-settings.json" ]]; then
  sed 's/\${ROUTATIC_PROXY_API_KEY}/sk-local-check-only/' \
    "${REPO_ROOT}/templates/routatic-proxy.config.json" > "${TMPDIR_CHECK}/config.json"
  if command -v routatic-proxy >/dev/null 2>&1 && routatic-proxy validate -c "${TMPDIR_CHECK}/config.json" >/dev/null 2>&1; then
    ok "templates/routatic-proxy.config.json (valid proxy config)"
  else
    fail "templates/routatic-proxy.config.json invalid"
  fi
  if grep -q 'ANTHROPIC_BASE_URL' "${REPO_ROOT}/templates/claude-settings.json" 2>/dev/null; then
    ok "templates/claude-settings.json"
  else
    fail "templates/claude-settings.json missing env block"
  fi
else
  fail "template files missing in repo"
fi
trap - EXIT
rm -rf "$TMPDIR_CHECK"

# 2. User proxy config exists
echo "[2] Proxy config on disk"
if [[ -f "$PROXY_CONFIG" ]]; then
  ok "Found ${PROXY_CONFIG}"
  if grep -q '\${ROUTATIC_PROXY_API_KEY}' "$PROXY_CONFIG" 2>/dev/null; then
    fail "api_key still placeholder — add your key or set ROUTATIC_PROXY_API_KEY"
  else
    ok "api_key looks set (not placeholder)"
  fi
else
  fail "Missing ${PROXY_CONFIG} — copy from templates/routatic-proxy.config.json"
fi

# 3. routatic-proxy validate (local only)
echo "[3] routatic-proxy validate"
if command -v routatic-proxy >/dev/null 2>&1; then
  if routatic-proxy validate 2>/dev/null; then
    ok "routatic-proxy validate"
  else
    fail "routatic-proxy validate — fix config.json"
  fi
else
  fail "routatic-proxy not installed"
fi

# 4. Claude settings
echo "[4] Claude Code settings"
if [[ -f "$CLAUDE_SETTINGS" ]]; then
  if grep -q '127.0.0.1:3456' "$CLAUDE_SETTINGS"; then
    ok "ANTHROPIC_BASE_URL points to local proxy"
  else
    fail "settings.json missing http://127.0.0.1:3456 in env"
  fi
else
  fail "Missing ${CLAUDE_SETTINGS}"
fi

# 5. Proxy health (free — no LLM call)
echo "[5] Proxy running (/health - no tokens)"
if curl -sf --max-time 3 http://127.0.0.1:3456/health >/dev/null 2>&1; then
  ok "Proxy responding on :3456"
else
  fail "Proxy not running — run: routatic-proxy serve -b"
fi

echo ""
echo "Result: ${PASS} passed, ${FAIL} failed"
[[ "$FAIL" -eq 0 ]]
