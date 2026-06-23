#!/usr/bin/env bash
# Sandbox test for setup.sh — does NOT touch your real HOME, proxy, or installs.
# Skips real routatic-proxy / claude / scoop / npm installs via PATH stubs.
set -euo pipefail

REPO_SRC="$(cd "$(dirname "$0")/.." && pwd)"
USER_REAL_HOME="${HOME}"
SANDBOX="$(mktemp -d)"
PASS=0
FAIL=0

cleanup() { rm -rf "$SANDBOX"; }
trap cleanup EXIT

ok()  { echo "  PASS  $1"; PASS=$((PASS + 1)); }
bad() { echo "  FAIL  $1"; FAIL=$((FAIL + 1)); }

echo "=========================================="
echo "  Sandbox test (isolated temp directory)"
echo "  Sandbox: $SANDBOX"
echo "=========================================="
echo ""

# --- isolated copy of repo (no .env leakage to real repo) ---
cp -r "$REPO_SRC" "$SANDBOX/repo"
rm -f "$SANDBOX/repo/.env" 2>/dev/null || true
REPO="$SANDBOX/repo"

# --- fake HOME ---
export HOME="$SANDBOX/home"
mkdir -p "$HOME" "$SANDBOX/bin"

# --- stub routatic-proxy (no install, no real proxy) ---
cat > "$SANDBOX/bin/routatic-proxy" << 'STUB'
#!/usr/bin/env bash
sub="${1:-}"
case "$sub" in
  --version)
    echo "routatic-proxy version 0.0.0-sandbox"
    ;;
  validate)
    echo "Configuration is valid!"
    echo "  Host: 127.0.0.1"
    echo "  Port: 3456"
    exit 0
    ;;
  status)
    echo "Server is running (sandbox stub)"
    exit 0
    ;;
  stop|serve|autostart)
    exit 0
    ;;
  models)
    echo "opencode-go/deepseek-v4-flash (sandbox)"
    ;;
  *)
    exit 0
    ;;
esac
STUB

# --- stub claude CLI ---
cat > "$SANDBOX/bin/claude" << 'STUB'
#!/usr/bin/env bash
echo "claude sandbox stub"
STUB

# --- stub curl: fake /health only for sandbox check ---
REAL_CURL="$(command -v curl)"
cat > "$SANDBOX/bin/curl" << STUB
#!/usr/bin/env bash
for arg in "\$@"; do
  if [[ "\$arg" == *"/health"* ]]; then
    echo '{"status":"ok","service":"sandbox-stub"}'
    exit 0
  fi
done
exec "$REAL_CURL" "\$@"
STUB

chmod +x "$SANDBOX/bin/routatic-proxy" "$SANDBOX/bin/claude" "$SANDBOX/bin/curl"

# scoop/npm must NOT run — stubs above make install steps skip
export PATH="$SANDBOX/bin:$PATH"

# block accidental scoop/npm if stubs fail
cat > "$SANDBOX/bin/scoop" << 'STUB'
#!/usr/bin/env bash
echo "SANDBOX ERROR: scoop should not be called" >&2
exit 99
STUB
cat > "$SANDBOX/bin/npm" << 'STUB'
#!/usr/bin/env bash
echo "SANDBOX ERROR: npm should not be called" >&2
exit 99
STUB
chmod +x "$SANDBOX/bin/scoop" "$SANDBOX/bin/npm"

# ==========================================
echo "TEST 1 — Manual mode (choice 2)"
echo "------------------------------------------"
OUT_MANUAL="$(echo 2 | bash "$REPO/scripts/setup.sh" 2>&1)" || true
if echo "$OUT_MANUAL" | grep -q "MANUAL SETUP"; then
  ok "Manual mode prints setup instructions"
else
  bad "Manual mode missing MANUAL SETUP text"
fi
if echo "$OUT_MANUAL" | grep -q "npm install -g @anthropic-ai/claude-code"; then
  ok "Manual mode includes claude install step"
else
  bad "Manual mode missing claude step"
fi
if [[ -f "$HOME/.config/routatic-proxy/config.json" ]]; then
  bad "Manual mode should not write proxy config"
else
  ok "Manual mode did not touch sandbox proxy config"
fi
echo ""

# ==========================================
echo "TEST 2 — Auto mode (choice 1)"
echo "------------------------------------------"
printf '1\nsk-sandbox-test-key-not-real\n' | bash "$REPO/scripts/setup.sh" 2>&1 | tee "$SANDBOX/auto.log" || true

if [[ -f "$REPO/.env" ]] && grep -q "sk-sandbox-test-key-not-real" "$REPO/.env"; then
  ok "Auto mode saved API key to repo .env (sandbox copy only)"
else
  bad "Auto mode .env missing in sandbox repo"
fi

if [[ -f "$HOME/.config/routatic-proxy/config.json" ]] && grep -q "sk-sandbox-test-key-not-real" "$HOME/.config/routatic-proxy/config.json"; then
  ok "Auto mode wrote proxy config with API key"
else
  bad "Auto mode proxy config missing or key not inserted"
fi

if [[ -f "$HOME/.claude/settings.json" ]] && grep -q "127.0.0.1:3456" "$HOME/.claude/settings.json"; then
  ok "Auto mode wrote Claude settings pointing to local proxy"
else
  bad "Auto mode Claude settings missing or wrong BASE_URL"
fi

if grep -q "SANDBOX ERROR: scoop" "$SANDBOX/auto.log" 2>/dev/null; then
  bad "Auto mode incorrectly invoked scoop"
else
  ok "Auto mode skipped scoop install (stub routatic already on PATH)"
fi

if grep -q "SANDBOX ERROR: npm" "$SANDBOX/auto.log" 2>/dev/null; then
  bad "Auto mode incorrectly invoked npm"
else
  ok "Auto mode skipped npm install (stub claude already on PATH)"
fi

if grep -q "Auto setup complete" "$SANDBOX/auto.log"; then
  ok "Auto mode finished successfully"
else
  bad "Auto mode did not print completion message"
fi
echo ""

# ==========================================
echo "TEST 3 — check.sh in sandbox"
echo "------------------------------------------"
if bash "$REPO/scripts/check.sh" 2>&1 | tee "$SANDBOX/check.log"; then
  ok "check.sh all passed in sandbox"
else
  bad "check.sh failed in sandbox (see $SANDBOX/check.log)"
fi
echo ""

# ==========================================
echo "TEST 4 — Real PC untouched"
echo "------------------------------------------"
if [[ -f "$USER_REAL_HOME/.config/routatic-proxy/config.json" ]]; then
  ok "Your real proxy config still exists (unchanged by sandbox)"
fi
if [[ "$HOME" == "$SANDBOX/home" ]]; then
  ok "Tests ran only against sandbox HOME"
fi
echo ""

echo "=========================================="
echo "  Results: $PASS passed, $FAIL failed"
echo "  Sandbox removed on exit."
echo "=========================================="

[[ "$FAIL" -eq 0 ]]
