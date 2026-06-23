# OpenCode Go + Claude Code CLI

Use your **OpenCode Go** subscription ($5/mo) with the **Claude Code CLI** — without Anthropic billing.

Claude Code speaks the Anthropic API. OpenCode Go speaks OpenAI-style endpoints. [routatic-proxy](https://github.com/routatic/proxy) sits in the middle and translates requests.

```
Claude Code CLI  →  routatic-proxy (localhost:3456)  →  OpenCode Go API
```

---

## Prerequisites

1. An [OpenCode Go](https://opencode.ai/docs/go/) subscription and API key
2. [Node.js](https://nodejs.org/) (for Claude Code CLI)
3. **Windows:** [Scoop](https://scoop.sh/)  
   **macOS/Linux:** [Homebrew](https://brew.sh/)

---

## Quick setup (one command)

### Windows (PowerShell)

```powershell
git clone https://github.com/abdullahmiraz/OPENCODE_CLAUDE_CLI.git
cd OPENCODE_CLAUDE_CLI
.\scripts\setup.ps1
```

### macOS / Linux / Git Bash

```bash
git clone https://github.com/abdullahmiraz/OPENCODE_CLAUDE_CLI.git
cd OPENCODE_CLAUDE_CLI
bash scripts/setup.sh
```

The script will:

1. Ask for your OpenCode Go API key (saved to `.env`, never committed)
2. Install `routatic-proxy` and `claude`
3. Write config files to your home directory
4. Start the proxy and run a smoke test

Then run:

```bash
claude
```

---

## Manual setup (step by step)

Follow these if you prefer to do it yourself or the script fails.

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

1. Copy the template:

   ```bash
   mkdir -p ~/.config/routatic-proxy
   cp templates/routatic-proxy.config.json ~/.config/routatic-proxy/config.json
   ```

2. Set your API key (pick one):

   ```bash
   export ROUTATIC_PROXY_API_KEY="sk-your-key-here"
   ```

   Or edit `~/.config/routatic-proxy/config.json` and replace `${ROUTATIC_PROXY_API_KEY}` with your key.

### Step 5 — Configure Claude Code

1. Copy the env block into `~/.claude/settings.json`:

   ```bash
   mkdir -p ~/.claude
   ```

   Merge `templates/claude-settings.json` into your existing `~/.claude/settings.json` under the `"env"` key.  
   If the file does not exist, copy the template as-is:

   ```bash
   cp templates/claude-settings.json ~/.claude/settings.json
   ```

2. The important values:

   | Variable | Value | Why |
   |----------|-------|-----|
   | `ANTHROPIC_BASE_URL` | `http://127.0.0.1:3456` | Point at local proxy |
   | `ANTHROPIC_AUTH_TOKEN` | `unused` | Proxy ignores this |
   | `ANTHROPIC_API_KEY` | *(empty)* | Auth handled by proxy |
   | `ANTHROPIC_MODEL` | `deepseek-v4-flash` | Default OpenCode Go model |
   | `ANTHROPIC_DEFAULT_SONNET_MODEL` | `deepseek-v4-flash` | Override Claude's Sonnet alias |
   | `ANTHROPIC_DEFAULT_OPUS_MODEL` | `deepseek-v4-pro` | Override Claude's Opus alias |
   | `ANTHROPIC_DEFAULT_HAIKU_MODEL` | `deepseek-v4-flash` | Override Claude's Haiku alias |

### Step 6 — Start the proxy

```bash
export ROUTATIC_PROXY_API_KEY="sk-your-key-here"
routatic-proxy serve -b
routatic-proxy status
```

Optional — start on login:

```bash
routatic-proxy autostart enable
```

### Step 7 — Verify

```bash
curl -X POST http://127.0.0.1:3456/v1/messages \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer unused" \
  -H "anthropic-version: 2023-06-01" \
  -d '{"model":"deepseek-v4-flash","max_tokens":256,"messages":[{"role":"user","content":"say ok"}]}'
```

You should get a JSON response with assistant text.

### Step 8 — Run Claude Code

```bash
claude
```

---

## Change models

Edit `~/.config/routatic-proxy/config.json`:

- **`models.default.model_id`** — main coding model
- **`models.complex.model_id`** — hard tasks / reasoning
- **`model_overrides`** — map Claude alias names to Go models

List available Go models:

```bash
routatic-proxy models
```

Or fetch from the API:

```bash
curl https://opencode.ai/zen/go/v1/models
```

Popular Go models: `deepseek-v4-flash`, `deepseek-v4-pro`, `kimi-k2.6`, `glm-5.1`, `minimax-m2.7`, `qwen3.5-plus`

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| `routing failed` / `no eligible model` | Raise `max_tokens` in the request; reasoning models need ≥256 tokens |
| `502 all models failed` | Check API key; run `routatic-proxy serve` in foreground and read logs |
| Claude still hits Anthropic | Confirm `ANTHROPIC_BASE_URL` is `http://127.0.0.1:3456`, not `opencode.ai` |
| Proxy not running | `routatic-proxy serve -b` or check autostart with `routatic-proxy autostart status` |
| Connection refused on 3456 | Start proxy first: `routatic-proxy serve -b` |

Logs: `~/.config/routatic-proxy/routatic-proxy.log`

Stop proxy: `routatic-proxy stop`

---

## File layout

```
OPENCODE_CLAUDE_CLI/
├── README.md
├── .env.example              # copy to .env with your key (gitignored)
├── templates/
│   ├── claude-settings.json  # Claude Code env vars
│   └── routatic-proxy.config.json
└── scripts/
    ├── setup.sh              # bash / Git Bash
    └── setup.ps1             # Windows PowerShell
```

**Never commit** `.env` or files containing your API key.

---

## How it works

- Claude Code sends Anthropic-format requests to `localhost:3456`
- routatic-proxy picks an OpenCode Go model (by scenario or override)
- Requests are translated to OpenAI/Anthropic format and sent to `https://opencode.ai/zen/go/v1`
- Responses are translated back so Claude Code thinks it talked to Anthropic

---

## Links

- [OpenCode Go docs](https://opencode.ai/docs/go/)
- [routatic-proxy](https://github.com/routatic/proxy)
- [Claude Code docs](https://docs.anthropic.com/en/docs/claude-code)
