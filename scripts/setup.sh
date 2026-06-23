#!/usr/bin/env bash
# OpenCode Go or Zen + Claude Code setup — auto (fast) or guided (yes/no per step).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CLAUDE_DIR="${HOME}/.claude"
PROXY_DIR="${HOME}/.config/routatic-proxy"
ENV_FILE="${REPO_ROOT}/.env"

info()  { echo "  $*"; }
step()  { echo ""; echo "==> $*"; }
fail()  { echo ""; echo "BLOCKED: $*" >&2; echo "Fix the issue above, then run this script again." >&2; exit 1; }

confirm() {
  local msg="$1"
  read -rp "${msg} [Y/n] (y or Enter=yes, n=no): " ans
  [[ -z "$ans" || "${ans,,}" == "y" || "${ans,,}" == "yes" ]]
}

OPENCODE_PLAN=""
SETUP_MODE=""

choose_plan() {
  if [[ -f "$ENV_FILE" ]]; then
    # shellcheck disable=SC1090
    source "$ENV_FILE"
  fi
  if [[ -n "${OPENCODE_PLAN:-}" && "${OPENCODE_PLAN}" =~ ^(go|zen)$ ]]; then
    return 0
  fi
  echo "==========================================" >&2
  echo "  OpenCode + Claude Code setup" >&2
  echo "==========================================" >&2
  echo "" >&2
  echo "Which OpenCode plan?" >&2
  echo "  1) Go  — \$5/mo subscription (opencode.ai -> Zen -> Go)" >&2
  echo "  2) Zen — pay-as-you-go credits (opencode.ai -> Zen)" >&2
  echo "" >&2
  read -rp "Enter 1 or 2 [default 1]: " choice
  case "${choice:-1}" in
    1|go|Go|GO) OPENCODE_PLAN="go" ;;
    2|zen|Zen|ZEN) OPENCODE_PLAN="zen" ;;
    *) echo "Invalid choice. Enter 1 or 2." >&2; exit 1 ;;
  esac
}

choose_mode() {
  echo "" >&2
  echo "Setup style:" >&2
  echo "  1) Auto    — runs all steps automatically" >&2
  echo "  2) Guided  — same steps, asks yes/no before each one" >&2
  echo "" >&2
  read -rp "Enter 1 or 2: " choice
  case "${choice:-}" in
    1|auto|Auto|AUTO) SETUP_MODE="auto" ;;
    2|guided|Guided|GUIDED|manual|Manual|MANUAL) SETUP_MODE="guided" ;;
    *) echo "Invalid choice. Enter 1 or 2." >&2; exit 1 ;;
  esac
}

proxy_template() {
  if [[ "$OPENCODE_PLAN" == "zen" ]]; then
    echo "${REPO_ROOT}/templates/routatic-proxy.config.zen.json"
  else
    echo "${REPO_ROOT}/templates/routatic-proxy.config.json"
  fi
}

load_api_key() {
  if [[ -f "$ENV_FILE" ]]; then
    # shellcheck disable=SC1090
    source "$ENV_FILE"
  fi
  OPENCODE_API_KEY="${OPENCODE_API_KEY:-${OPENCODE_GO_API_KEY:-}}"
  if [[ -z "$OPENCODE_API_KEY" ]]; then
    step "STEP 1/8 — API key"
    if [[ "$OPENCODE_PLAN" == "zen" ]]; then
      info "Get it from: https://opencode.ai -> Zen"
    else
      info "Get it from: https://opencode.ai -> Zen -> Go"
    fi
    info "Paste your key and press Enter (saved to .env, gitignored)"
    read -rp "  API key: " OPENCODE_API_KEY
    [[ -n "$OPENCODE_API_KEY" ]] || fail "API key is required."
    {
      echo "OPENCODE_PLAN=${OPENCODE_PLAN}"
      echo "OPENCODE_API_KEY=${OPENCODE_API_KEY}"
    } > "$ENV_FILE"
    chmod 600 "$ENV_FILE"
    info "Saved to ${ENV_FILE}"
  else
    step "STEP 1/8 — API key"
    info "Using key from ${ENV_FILE} (${OPENCODE_PLAN} plan)"
    if [[ -z "${OPENCODE_PLAN:-}" ]]; then
      OPENCODE_PLAN="go"
    fi
    if ! grep -q '^OPENCODE_PLAN=' "$ENV_FILE" 2>/dev/null || ! grep -q '^OPENCODE_API_KEY=' "$ENV_FILE" 2>/dev/null; then
      {
        echo "OPENCODE_PLAN=${OPENCODE_PLAN}"
        echo "OPENCODE_API_KEY=${OPENCODE_API_KEY}"
      } > "$ENV_FILE"
      chmod 600 "$ENV_FILE"
    fi
  fi
  export ROUTATIC_PROXY_API_KEY="$OPENCODE_API_KEY"
}

install_routatic() {
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
  mkdir -p "$PROXY_DIR"
  cp "$(proxy_template)" "${PROXY_DIR}/config.json"
  local cfg
  cfg="$(to_native_path "${PROXY_DIR}/config.json")"
  if command -v node >/dev/null 2>&1; then
    PROXY_CFG="$cfg" API_KEY="$OPENCODE_API_KEY" node -e "
      const fs=require('fs');
      const p=process.env.PROXY_CFG;
      let j=fs.readFileSync(p,'utf8');
      j=j.replace('\${ROUTATIC_PROXY_API_KEY}',process.env.API_KEY);
      fs.writeFileSync(p,j);
    "
  elif command -v python3 >/dev/null 2>&1; then
    PROXY_CFG="$cfg" API_KEY="$OPENCODE_API_KEY" python3 -c "
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
  routatic-proxy stop 2>/dev/null || true
  ROUTATIC_PROXY_API_KEY="$OPENCODE_API_KEY" routatic-proxy serve -b
  sleep 2
  routatic-proxy status
}

enable_autostart() {
  routatic-proxy autostart enable 2>/dev/null || info "Autostart not supported on this OS (start manually after reboot)."
}

verify_setup() {
  bash "${REPO_ROOT}/scripts/check.sh" || true
}

print_done() {
  local label="$1"
  echo ""
  echo "=========================================="
  echo "  ${label} setup complete. Run:  claude"
  echo "  After reboot:             claude"
  echo "    (if autostart worked)   or: routatic-proxy serve -b"
  echo "  Re-check:                 bash scripts/check.sh"
  echo "=========================================="
}

run_auto() {
  load_api_key
  step "STEP 2/8 — Install routatic-proxy"
  install_routatic
  step "STEP 3/8 — Install Claude Code CLI"
  install_claude
  step "STEP 4/8 — Write proxy config -> ${PROXY_DIR}/config.json"
  write_proxy_config
  step "STEP 5/8 — Write Claude settings -> ${CLAUDE_DIR}/settings.json"
  write_claude_settings
  step "STEP 6/8 — Start routatic-proxy on http://127.0.0.1:3456"
  start_proxy
  step "STEP 7/8 — Enable autostart on login"
  enable_autostart
  step "STEP 8/8 — Verify (local checks only, no tokens)"
  verify_setup
  print_done "Auto"
}

run_guided() {
  echo ""
  echo "Guided setup — confirm each step: y or Enter = yes, n = no."
  echo "  Proxy config  -> ${PROXY_DIR}/config.json"
  echo "  Claude config -> ${CLAUDE_DIR}/settings.json"
  echo ""

  load_api_key

  step "STEP 2/8 — Install routatic-proxy"
  if command -v routatic-proxy >/dev/null 2>&1; then
    info "Already installed: $(routatic-proxy --version 2>/dev/null || true)"
  elif confirm "  Install routatic-proxy now?"; then
    install_routatic
  else
    fail "Install routatic-proxy manually, then re-run this script."
  fi

  step "STEP 3/8 — Install Claude Code CLI"
  if command -v claude >/dev/null 2>&1; then
    info "Already installed."
  elif confirm "  Run: npm install -g @anthropic-ai/claude-code ?"; then
    install_claude
  else
    fail "Install claude manually, then re-run this script."
  fi

  step "STEP 4/8 — Copy proxy config"
  info "FROM: $(proxy_template)"
  info "TO:   ${PROXY_DIR}/config.json"
  if confirm "  Copy template and write your API key?"; then
    write_proxy_config
    info "Done."
  else
    info "Skipped — copy template yourself (see README)."
  fi

  step "STEP 5/8 — Claude Code settings"
  info "FROM: ${REPO_ROOT}/templates/claude-settings.json"
  info "TO:   ${CLAUDE_DIR}/settings.json"
  if confirm "  Copy or merge Claude settings?"; then
    write_claude_settings
    info "Done."
  else
    info "Skipped — merge template yourself (see README)."
  fi

  step "STEP 6/8 — Start routatic-proxy"
  if confirm "  Start proxy in background on http://127.0.0.1:3456 ?"; then
    start_proxy
  else
    info "Skipped — run later: routatic-proxy serve -b"
  fi

  step "STEP 7/8 — Autostart on login (optional)"
  if confirm "  Enable autostart?"; then
    enable_autostart
  else
    info "Skipped."
  fi

  verify_setup
  print_done "Guided"
}

choose_plan
choose_mode
if [[ "$SETUP_MODE" == "guided" ]]; then
  run_guided
else
  run_auto
fi
