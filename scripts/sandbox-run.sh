#!/usr/bin/env bash
# Interactive sandbox — run setup.sh safely and try the real user flow.
# Does NOT touch your real ~/.claude or ~/.config/routatic-proxy.
# Does NOT install routatic-proxy, claude, scoop, or npm (uses stubs).
set -euo pipefail

REPO_SRC="$(cd "$(dirname "$0")/.." && pwd)"
USER_REAL_HOME="${HOME}"
SANDBOX="$(mktemp -d -t opencode-claude-sandbox-XXXXXX)"

cleanup() {
  echo ""
  if [[ -d "$SANDBOX" ]]; then
    read -rp "Delete sandbox folder? [Y/n] " ans
    if [[ -z "$ans" || "${ans,,}" == "y" || "${ans,,}" == "yes" ]]; then
      rm -rf "$SANDBOX"
      echo "Sandbox removed."
    else
      echo "Kept at: $SANDBOX"
      echo "  fake HOME:  $SANDBOX/home"
      echo "  repo copy:  $SANDBOX/repo"
      echo "Delete later: rm -rf \"$SANDBOX\""
    fi
  fi
}
trap cleanup EXIT

echo "=========================================="
echo "  Interactive sandbox (safe UX test)"
echo "=========================================="
echo ""
echo "Your real PC is NOT modified:"
echo "  Real HOME:     $USER_REAL_HOME"
echo "  Sandbox HOME: $SANDBOX/home"
echo "  Sandbox repo:  $SANDBOX/repo"
echo ""
echo "Installs are faked (stubs). Use any fake API key, e.g.:"
echo "  sk-test-sandbox-not-real"
echo ""
echo "Try both modes:"
echo "  2 = Guided (yes/no before each step)"
echo "  1 = Auto   (runs everything)"
echo ""
read -rp "Press Enter to start setup.sh in sandbox... "
echo ""

# --- copy repo (keeps your real repo .env untouched) ---
cp -r "$REPO_SRC" "$SANDBOX/repo"
rm -f "$SANDBOX/repo/.env" 2>/dev/null || true

export HOME="$SANDBOX/home"
mkdir -p "$HOME" "$SANDBOX/bin"

# --- stubs ---
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
echo "claude sandbox stub — real claude not invoked"
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
echo "ERROR: scoop should not run in sandbox" >&2
exit 99
STUB

cat > "$SANDBOX/bin/npm" << 'STUB'
#!/usr/bin/env bash
echo "ERROR: npm should not run in sandbox" >&2
exit 99
STUB

chmod +x "$SANDBOX/bin"/*
export PATH="$SANDBOX/bin:$PATH"

cd "$SANDBOX/repo"
bash scripts/setup.sh
SETUP_EXIT=$?

echo ""
echo "=========================================="
echo "  setup.sh exited with code: $SETUP_EXIT"
echo "=========================================="
echo ""
echo "Sandbox files written (if you chose Auto):"
echo "  $HOME/.config/routatic-proxy/config.json"
echo "  $HOME/.claude/settings.json"
echo "  $SANDBOX/repo/.env"
echo ""
if [[ -f "$HOME/.config/routatic-proxy/config.json" ]]; then
  echo "--- proxy config (first 5 lines) ---"
  head -5 "$HOME/.config/routatic-proxy/config.json"
  echo ""
fi
if [[ -f "$HOME/.claude/settings.json" ]]; then
  echo "--- claude settings ---"
  cat "$HOME/.claude/settings.json"
  echo ""
fi
echo "Re-run checks in sandbox:"
echo "  cd \"$SANDBOX/repo\" && HOME=\"$HOME\" PATH=\"$SANDBOX/bin:\$PATH\" bash scripts/check.sh"
echo ""
echo "Your real configs (unchanged):"
echo "  $USER_REAL_HOME/.config/routatic-proxy/config.json"
echo "  $USER_REAL_HOME/.claude/settings.json"
echo ""

exit "$SETUP_EXIT"
