#!/usr/bin/env bash
# Automated sandbox tests — isolated temp HOME, stub installs, no tokens.
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

setup_sandbox_env() {
  cp -r "$REPO_SRC" "$SANDBOX/repo"
  rm -f "$SANDBOX/repo/.env" 2>/dev/null || true
  REPO="$SANDBOX/repo"
  export HOME="$SANDBOX/home"
  mkdir -p "$HOME" "$SANDBOX/bin"

  cat > "$SANDBOX/bin/routatic-proxy" << 'STUB'
#!/usr/bin/env bash
case "${1:-}" in
  --version) echo "routatic-proxy version 0.0.0-sandbox" ;;
  validate)
    echo "Configuration is valid!"
    echo "  Host: 127.0.0.1"
    echo "  Port: 3456"
    exit 0
    ;;
  status) echo "Server is running (sandbox stub)"; exit 0 ;;
  stop|serve|autostart) exit 0 ;;
  models) echo "opencode-go/deepseek-v4-flash (sandbox)" ;;
  *) exit 0 ;;
esac
STUB

  cat > "$SANDBOX/bin/claude" << 'STUB'
#!/usr/bin/env bash
echo "claude sandbox stub"
STUB

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

  chmod +x "$SANDBOX/bin"/*
  export PATH="$SANDBOX/bin:$PATH"
}

echo "=========================================="
echo "  Sandbox test (isolated temp directory)"
echo "  Sandbox: $SANDBOX"
echo "=========================================="
echo ""

setup_sandbox_env

echo "TEST 1 — Guided mode (choice 2, yes/no consent)"
echo "------------------------------------------"
# Pauses need bare Enter; confirms need y+Enter (alternating)
GUIDED_INPUT=$'2\nsk-sandbox-guided-key\ny\ny\ny\ny\n'
OUT_GUIDED="$(printf '%s' "$GUIDED_INPUT" | bash "$REPO/scripts/setup.sh" 2>&1)" || true
if echo "$OUT_GUIDED" | grep -q "Guided setup"; then
  ok "Guided mode shows consent flow"
else
  bad "Guided mode missing Guided setup header"
fi
if echo "$OUT_GUIDED" | grep -q "Guided setup complete"; then
  ok "Guided mode completes when confirmed"
else
  bad "Guided mode did not complete"
fi
if [[ -f "$HOME/.config/routatic-proxy/config.json" ]] && grep -q "sk-sandbox-guided-key" "$HOME/.config/routatic-proxy/config.json"; then
  ok "Guided mode wrote proxy config after consent"
else
  bad "Guided mode did not write proxy config"
fi
echo ""

echo "TEST 2 — Auto mode (choice 1)"
echo "------------------------------------------"
cp -r "$REPO_SRC" "$SANDBOX/repo-auto"
rm -f "$SANDBOX/repo-auto/.env" 2>/dev/null || true
export HOME="$SANDBOX/home-auto"
mkdir -p "$HOME"
printf '1\nsk-sandbox-auto-key\n' | bash "$SANDBOX/repo-auto/scripts/setup.sh" 2>&1 | tee "$SANDBOX/auto.log" || true

if [[ -f "$HOME/.config/routatic-proxy/config.json" ]] && grep -q "sk-sandbox-auto-key" "$HOME/.config/routatic-proxy/config.json"; then
  ok "Auto mode wrote proxy config with API key"
else
  bad "Auto mode proxy config missing"
fi
if grep -q "Auto setup complete" "$SANDBOX/auto.log"; then
  ok "Auto mode finished successfully"
else
  bad "Auto mode did not complete"
fi
if grep -q "SANDBOX ERROR: scoop" "$SANDBOX/auto.log" 2>/dev/null; then
  bad "Auto mode incorrectly invoked scoop"
else
  ok "Auto mode skipped real installs (stubs on PATH)"
fi
echo ""

echo "TEST 3 — check.sh in sandbox"
echo "------------------------------------------"
export HOME="$SANDBOX/home-auto"
if bash "$SANDBOX/repo-auto/scripts/check.sh" 2>&1 | tee "$SANDBOX/check.log"; then
  ok "check.sh passed"
else
  bad "check.sh failed"
fi
echo ""

echo "TEST 4 — Real PC untouched"
echo "------------------------------------------"
ok "Sandbox HOME only: $SANDBOX/home*"
echo ""

echo "=========================================="
echo "  Results: $PASS passed, $FAIL failed"
echo "=========================================="
[[ "$FAIL" -eq 0 ]]
