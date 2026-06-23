# OpenCode Go + Claude Code CLI

Use your **OpenCode Go** subscription ($5/mo) with the **Claude Code CLI** — without Anthropic billing.

Claude Code speaks the Anthropic API. OpenCode Go does not. [routatic-proxy](https://github.com/routatic/proxy) sits in the middle and translates requests.

```
Claude Code CLI  →  routatic-proxy (localhost:3456)  →  OpenCode Go API
```

> **New to this?** See [BEGINNER-SETUP.md](BEGINNER-SETUP.md) for a longer guide (paths, Scoop, what each file does).

---

## Prerequisites

1. [OpenCode Go](https://opencode.ai/docs/go/) subscription and API key
2. [Node.js](https://nodejs.org/) (for Claude Code CLI)
3. **Windows:** [Scoop](https://scoop.sh/)  
   **macOS/Linux:** [Homebrew](https://brew.sh/)

---

## Quick setup (script)

Run the script and **choose 1 (auto) or 2 (guided)**:

- **Auto** — installs routatic-proxy, Claude CLI, writes configs, starts proxy (no prompts)  
- **Guided** — same steps, asks **y/Enter=yes** or **n=no** before each one (your consent)  

If auto mode is blocked (e.g. Scoop or Node missing), it tells you what to install, then re-run the script.

**Windows (PowerShell):**

```powershell
git clone https://github.com/abdullahmiraz/OPENCODE_CLAUDE_CLI.git
cd OPENCODE_CLAUDE_CLI
.\scripts\setup.ps1
```

**macOS / Linux / Git Bash:**

```bash
git clone https://github.com/abdullahmiraz/OPENCODE_CLAUDE_CLI.git
cd OPENCODE_CLAUDE_CLI
bash scripts/setup.sh
```

Then run:

```bash
claude
```

Check everything (no API calls, no tokens):

```bash
.\scripts\check.ps1    # Windows
bash scripts/check.sh  # Bash
```

---

## Manual setup

### Step 1 — Get your OpenCode Go API key

1. Go to [opencode.ai](https://opencode.ai)
2. Sign in → **Zen** → subscribe to **Go**
3. Copy your API key

### Step 2 — Install routatic-proxy

**Windows (Scoop):**

```powershell
scoop bucket add routatic https://github.com/routatic/scoop-bucket
scoop install routatic-proxy
```

**macOS / Linux (Homebrew):**

```bash
brew tap routatic/tap
brew install routatic-proxy
```

### Step 3 — Install Claude Code CLI

```bash
npm install -g @anthropic-ai/claude-code
```

### Step 4 — Configure routatic-proxy

```bash
mkdir -p ~/.config/routatic-proxy
cp templates/routatic-proxy.config.json ~/.config/routatic-proxy/config.json
```

Open `~/.config/routatic-proxy/config.json` and set your API key (replace `${ROUTATIC_PROXY_API_KEY}` with your real key).

Or set an env var when starting the proxy:

```bash
export ROUTATIC_PROXY_API_KEY="sk-your-key-here"
```

### Step 5 — Configure Claude Code

```bash
mkdir -p ~/.claude
cp templates/claude-settings.json ~/.claude/settings.json
```

If you already have `~/.claude/settings.json`, merge the `"env"` block from the template into it.

Key values:

| Variable | Value |
|----------|-------|
| `ANTHROPIC_BASE_URL` | `http://127.0.0.1:3456` |
| `ANTHROPIC_AUTH_TOKEN` | `unused` |
| `ANTHROPIC_API_KEY` | *(empty)* |
| `ANTHROPIC_MODEL` | `deepseek-v4-flash` |
| `ANTHROPIC_DEFAULT_SONNET_MODEL` | `deepseek-v4-flash` |
| `ANTHROPIC_DEFAULT_OPUS_MODEL` | `deepseek-v4-pro` |
| `ANTHROPIC_DEFAULT_HAIKU_MODEL` | `deepseek-v4-flash` |

### Step 6 — Start the proxy

```bash
routatic-proxy serve -b
routatic-proxy status
```

Optional autostart:

```bash
routatic-proxy autostart enable
```

### Step 7 — Verify

```bash
curl http://127.0.0.1:3456/health
```

You should see `"status":"ok"`.

### Step 8 — Run Claude Code

```bash
claude
```

---

## Change models

Edit `~/.config/routatic-proxy/config.json`:

- `models.default.model_id` — main model
- `models.complex.model_id` — hard tasks
- `model_overrides` — map Claude names to Go models

```bash
routatic-proxy models
```

Popular Go models: `deepseek-v4-flash`, `deepseek-v4-pro`, `kimi-k2.6`, `glm-5.1`, `minimax-m2.7`, `qwen3.5-plus`

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| Connection refused on 3456 | `routatic-proxy serve -b` |
| Claude still hits Anthropic | `ANTHROPIC_BASE_URL` must be `http://127.0.0.1:3456` |
| `validate` fails on placeholder key | Put your real key in `config.json` |
| `routing failed` | Use `max_tokens` ≥ 256 for reasoning models |

Logs: `~/.config/routatic-proxy/routatic-proxy.log`  
Stop proxy: `routatic-proxy stop`

---

## Repo layout

```
OPENCODE_CLAUDE_CLI/
├── README.md
├── BEGINNER-SETUP.md          ← detailed guide for new users
├── templates/
│   ├── routatic-proxy.config.json
│   └── claude-settings.json
└── scripts/
    ├── setup.ps1 / setup.sh   ← auto or guided (yes/no)
    ├── check.ps1 / check.sh
    ├── sandbox-run.sh         ← try setup yourself (safe, interactive)
    └── test-sandbox.sh        ← automated sandbox tests
```

Never commit `.env` or a config file with your real API key.

---

## Links

- [OpenCode Go docs](https://opencode.ai/docs/go/)
- [routatic-proxy](https://github.com/routatic/proxy)
- [Claude Code docs](https://docs.anthropic.com/en/docs/claude-code)

---

## Contact

Questions or issues? Reach out on [LinkedIn](https://www.linkedin.com/in/abdullahmiraz/).
