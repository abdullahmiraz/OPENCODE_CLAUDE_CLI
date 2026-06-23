#!/usr/bin/env bash
# OpenCode Go + Claude Code setup — choose auto or manual at start.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CLAUDE_DIR="${HOME}/.claude"
PROXY_DIR="${HOME}/.config/routatic-proxy"
ENV_FILE="${REPO_ROOT}/.env"

info()  { echo "  $*"; }
step()  { echo ""; echo "==> $*"; }
fail()  { echo ""; echo "BLOCKED: $*" >&2; echo "Fix the issue above, then run this script again." >&2; exit 1; }

show_manual() {
  cat <<'EOF'

MANUAL SETUP — do these steps yourself, then run: claude

  1. Get API key from https://opencode.ai (Zen -> Go)

  2. Install routatic-proxy
       Windows:  scoop bucket add routatic https://github.com/routatic/scoop-bucket
                 scoop install routatic-proxy
       Mac/Linux: brew tap routatic/tap && brew install routatic-proxy

  3. Install Claude Code CLI
       npm install -g @anthropic-ai/claude-code

  4. Copy proxy config
       mkdir -p ~/.config/routatic-proxy
       cp templates/routatic-proxy.config.json ~/.config/routatic-proxy/config.json
       Edit that file and set your api_key

  5. Copy Claude settings
       mkdir -p ~/.claude
       cp templates/claude-settings.json ~/.claude/settings.json
       (or merge the "env" block if you already have settings.json)

  6. Start proxy
       routatic-proxy serve -b

  7. Verify (no tokens)
       bash scripts/check.sh

  8. Run
       claude

Full details: BEGINNER-SETUP.md or README.md

EOF
}

SETUP_MODE=""
choose_mode() {
  echo "==========================================" >&2
  echo "  OpenCode Go + Claude Code setup" >&2
  echo "==========================================" >&2
  echo "" >&2
  echo "Choose one:" >&2
  echo "  1) Auto   — script installs and configures everything" >&2
  echo "  2) Manual — print steps, you do them yourself" >&2
  echo "" >&2
  read -rp "Enter 1 or 2: " choice
  case "${choice:-}" in
    1|auto|Auto|AUTO) SETUP_MODE="auto" ;;
    2|manual|Manual|MANUAL) SETUP_MODE="manual" ;;
    *) echo "Invalid choice. Enter 1 or 2." >&2; exit 1 ;;
  esac
}

load_api_key() {
  if [[ -f "$ENV_FILE" ]]; then
    # shellcheck disable=SC1090
    source "$ENV_FILE"
  fi
  if [[ -z "${OPENCODE_GO_API_KEY:-}" ]]; then
    step "API key"
    info "Get it from: https://opencode.ai -> Zen -> Go"
    read -rsp "Paste your API key: " OPENCODE_GO_API_KEY
    echo ""
    [[ -n "$OPENCODE_GO_API_KEY" ]] || fail "API key is required."
    echo "OPENCODE_GO_API_KEY=${OPENCODE_GO_API_KEY}" > "$ENV_FILE"
    chmod 600 "$ENV_FILE"
    info "Saved to ${ENV_FILE}"
  else
    step "API key"
    info "Using key from ${ENV_FILE}"
  fi
  export ROUTATIC_PROXY_API_KEY="$OPENCODE_GO_API_KEY"
}

install_routatic() {
  step "Install routatic-proxy"
  if command -v routatic-proxy >/dev/null 2>&1; then
    info "Already installed: $(routatic-proxy --version 2>/dev/null || true)"
    return 0
  fi
  if command -v scoop >/dev/null 2>&1; then
    scoop bucket add routatic https://github.com/routatic/scoop-bucket 2>/dev/null || true
    scoop install routatic-proxy
    return 0
  fi
  if command -v brew >/dev/null 2>&1; then
    brew tap routatic/tap && brew install routatic-proxy
    return 0
  fi
  fail "No package manager found.
  Windows: install Scoop from https://scoop.sh then re-run this script.
  Mac/Linux: install Homebrew from https://brew.sh then re-run.
  Or download routatic-proxy from https://github.com/routatic/proxy/releases"
}

install_claude() {
  step "Install Claude Code CLI"
  if command -v claude >/dev/null 2>&1; then
    info "Already installed."
    return 0
  fi
  if ! command -v npm >/dev/null 2>&1; then
    fail "npm not found. Install Node.js from https://nodejs.org then re-run this script."
  fi
  npm install -g @anthropic-ai/claude-code
}

to_native_path() {
  if command -v cygpath >/dev/null 2>&1; then
    cygpath -m "$1"
  else
    echo "$1"
  fi
}

write_proxy_config() {
  step "Write proxy config -> ${PROXY_DIR}/config.json"
  mkdir -p "$PROXY_DIR"
  cp "${REPO_ROOT}/templates/routatic-proxy.config.json" "${PROXY_DIR}/config.json"
  local cfg
  cfg="$(to_native_path "${PROXY_DIR}/config.json")"
  if command -v node >/dev/null 2>&1; then
    PROXY_CFG="$cfg" API_KEY="$OPENCODE_GO_API_KEY" node -e "
      const fs=require('fs');
      const p=process.env.PROXY_CFG;
      let j=fs.readFileSync(p,'utf8');
      j=j.replace('\${ROUTATIC_PROXY_API_KEY}',process.env.API_KEY);
      fs.writeFileSync(p,j);
    "
  elif command -v python3 >/dev/null 2>&1; then
    PROXY_CFG="$cfg" API_KEY="$OPENCODE_GO_API_KEY" python3 -c "
import os, pathlib
p=pathlib.Path(os.environ['PROXY_CFG'])
p.write_text(p.read_text().replace('\${ROUTATIC_PROXY_API_KEY}', os.environ['API_KEY']))
"
  else
    fail "Need node or python3 to insert API key. Edit ${PROXY_DIR}/config.json manually, then re-run."
  fi
  info "Done."
}

write_claude_settings() {
  step "Write Claude settings -> ${CLAUDE_DIR}/settings.json"
  mkdir -p "$CLAUDE_DIR"
  local settings template
  settings="$(to_native_path "${CLAUDE_DIR}/settings.json")"
  template="$(to_native_path "${REPO_ROOT}/templates/claude-settings.json")"
  if [[ -f "${CLAUDE_DIR}/settings.json" ]] && command -v node >/dev/null 2>&1; then
    local backup="${CLAUDE_DIR}/settings.json.backup.$(date +%s)"
    cp "${CLAUDE_DIR}/settings.json" "$backup"
    info "Backed up to ${backup}"
    SETTINGS_PATH="$settings" TEMPLATE_PATH="$template" node -e "
      const fs=require('fs');
      const cur=JSON.parse(fs.readFileSync(process.env.SETTINGS_PATH,'utf8'));
      const tpl=JSON.parse(fs.readFileSync(process.env.TEMPLATE_PATH,'utf8'));
      cur.env={...cur.env,...tpl.env};
      fs.writeFileSync(process.env.SETTINGS_PATH,JSON.stringify(cur,null,2)+'\n');
    "
  elif [[ -f "${CLAUDE_DIR}/settings.json" ]]; then
    fail "Existing settings.json found but node is missing. Merge templates/claude-settings.json manually, then re-run."
  else
    cp "${REPO_ROOT}/templates/claude-settings.json" "${CLAUDE_DIR}/settings.json"
  fi
  info "Done."
}

start_proxy() {
  step "Start routatic-proxy on http://127.0.0.1:3456"
  routatic-proxy stop 2>/dev/null || true
  ROUTATIC_PROXY_API_KEY="$OPENCODE_GO_API_KEY" routatic-proxy serve -b
  sleep 2
  routatic-proxy status
}

enable_autostart() {
  step "Enable autostart on login"
  routatic-proxy autostart enable 2>/dev/null || info "Autostart not supported on this OS (start manually after reboot)."
}

verify_setup() {
  step "Verify (local checks only, no tokens)"
  bash "${REPO_ROOT}/scripts/check.sh" || true
}

run_auto() {
  load_api_key
  install_routatic
  install_claude
  write_proxy_config
  write_claude_settings
  start_proxy
  enable_autostart
  verify_setup
  echo ""
  echo "=========================================="
  echo "  Auto setup complete. Run:  claude"
  echo "  After reboot:             claude"
  echo "    (if autostart worked)   or: routatic-proxy serve -b"
  echo "  Re-check:                 bash scripts/check.sh"
  echo "=========================================="
}

choose_mode
if [[ "$SETUP_MODE" == "manual" ]]; then
  show_manual
  exit 0
fi

run_auto
