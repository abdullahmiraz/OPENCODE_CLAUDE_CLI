# Beginner setup guide

**This guide is for new or inexperienced users.**  
If you already know your way around the terminal, use the short [README.md](README.md) instead.

It explains:

- **Go vs Zen** — which OpenCode plan you have and which template to use
- What `~/.config/routatic-proxy/config.json` is and where it comes from
- What Scoop is and how to install it (Windows)
- Two ways to set up: **guided** (yes/no before each step) or **auto** (runs everything)
- How to verify without spending API credits

---

## What you are building

```
Claude Code  →  routatic-proxy (your PC, port 3456)  →  OpenCode Go or Zen
```

Claude Code thinks it talks to Anthropic. The proxy translates requests to OpenCode models.

You need **one** of these OpenCode plans:

| Plan | What it is | API key from |
|------|------------|--------------|
| **Go** | $5/month subscription, flat rate | [opencode.ai](https://opencode.ai) → Zen → **Go** |
| **Zen** | Pay-as-you-go credits | [opencode.ai](https://opencode.ai) → **Zen** |

Same API key account on OpenCode — but the proxy must use the **right template** for your plan (Go and Zen hit different endpoints).

---

## What you need first

1. [OpenCode Go](https://opencode.ai/docs/go/) **or** [OpenCode Zen](https://opencode.ai) account + API key  
2. [Node.js](https://nodejs.org/) — for the `claude` command  
3. **Windows:** Scoop (installs `routatic-proxy`) — see below  
   **Mac/Linux:** [Homebrew](https://brew.sh/)

---

## Where do these files come from?

Docs use `~` as shorthand for **your user folder**.

| Shorthand | Windows | What it is |
|-----------|---------|------------|
| `~` | `C:\Users\YOUR_NAME` | Your home folder |
| `~/.config/routatic-proxy/config.json` | `C:\Users\YOUR_NAME\.config\routatic-proxy\config.json` | Proxy settings |
| `~/.claude/settings.json` | `C:\Users\YOUR_NAME\.claude\settings.json` | Claude Code settings |

**You do not download `config.json` from the internet.**

Both files come from **this repo**:

```
OPENCODE_CLAUDE_CLI/templates/routatic-proxy.config.json       ← Go plan
OPENCODE_CLAUDE_CLI/templates/routatic-proxy.config.zen.json   ← Zen plan
OPENCODE_CLAUDE_CLI/templates/claude-settings.json               ← copy or merge this
```

Pick **one** proxy template — Go subscribers use `.json`, Zen-only users use `.zen.json`. Claude settings are the same for both.

**Open the proxy folder in File Explorer (Windows):**

1. Press `Win + R`
2. Paste: `%USERPROFILE%\.config\routatic-proxy`
3. Press Enter — create the folder if needed, then put `config.json` there

---

## What is Scoop? (Windows only)

**Scoop** is a simple installer for Windows command-line tools. We use it to install `routatic-proxy`.

**Install Scoop once** — open PowerShell and run:

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression
```

Check it worked:

```powershell
scoop --version
```

**Don't want Scoop?** Download `routatic-proxy` from [GitHub releases](https://github.com/routatic/proxy/releases) and skip Scoop steps.

---

# Option A — Manual setup (you do every step)

### Step 1 — Get your OpenCode API key

**If you have Go ($5/mo):**

1. Open [opencode.ai](https://opencode.ai)  
2. Sign in → **Zen** → subscribe to **Go**  
3. Copy your API key (`sk-...`)

**If you have Zen only (pay-as-you-go):**

1. Open [opencode.ai](https://opencode.ai)  
2. Sign in → **Zen**  
3. Copy your API key (`sk-...`)

Never commit your key to git or share it publicly.

---

### Step 2 — Install routatic-proxy

**Windows (PowerShell):**

```powershell
scoop bucket add routatic https://github.com/routatic/scoop-bucket
scoop install routatic-proxy
routatic-proxy --version
```

**Mac / Linux:**

```bash
brew tap routatic/tap
brew install routatic-proxy
routatic-proxy --version
```

If you see a version number, it worked. If not, close the terminal and try again.

---

### Step 3 — Install Claude Code CLI

```bash
npm install -g @anthropic-ai/claude-code
claude --version
```

---

### Step 4 — Create proxy config

From the folder where you cloned this repo, copy the template that matches **your plan**:

| Your plan | Template file |
|-----------|---------------|
| Go | `templates/routatic-proxy.config.json` |
| Zen | `templates/routatic-proxy.config.zen.json` |

**Git Bash / Mac / Linux (Go):**

```bash
cd OPENCODE_CLAUDE_CLI
mkdir -p ~/.config/routatic-proxy
cp templates/routatic-proxy.config.json ~/.config/routatic-proxy/config.json
```

**Git Bash / Mac / Linux (Zen):**

```bash
cd OPENCODE_CLAUDE_CLI
mkdir -p ~/.config/routatic-proxy
cp templates/routatic-proxy.config.zen.json ~/.config/routatic-proxy/config.json
```

**Windows PowerShell (Go):**

```powershell
cd OPENCODE_CLAUDE_CLI
New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\.config\routatic-proxy"
Copy-Item templates\routatic-proxy.config.json "$env:USERPROFILE\.config\routatic-proxy\config.json"
```

**Windows PowerShell (Zen):**

```powershell
cd OPENCODE_CLAUDE_CLI
New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\.config\routatic-proxy"
Copy-Item templates\routatic-proxy.config.zen.json "$env:USERPROFILE\.config\routatic-proxy\config.json"
```

**Add your API key** — open the file you just created and find:

```json
"api_key": "${ROUTATIC_PROXY_API_KEY}",
```

Change it to:

```json
"api_key": "sk-your-actual-key-here",
```

Save. Then check (no API call, no tokens):

```bash
routatic-proxy validate
```

---

### Step 5 — Configure Claude Code

**No settings file yet:**

```bash
mkdir -p ~/.claude
cp templates/claude-settings.json ~/.claude/settings.json
```

**Already have settings** — open `~/.claude/settings.json` and merge the `"env"` block from `templates/claude-settings.json`.

Claude must point at the **local proxy**, not Anthropic:

```json
"env": {
  "ANTHROPIC_BASE_URL": "http://127.0.0.1:3456",
  "ANTHROPIC_AUTH_TOKEN": "unused",
  "ANTHROPIC_API_KEY": "",
  "ANTHROPIC_MODEL": "deepseek-v4-flash",
  "ANTHROPIC_DEFAULT_SONNET_MODEL": "deepseek-v4-flash",
  "ANTHROPIC_DEFAULT_OPUS_MODEL": "deepseek-v4-pro",
  "ANTHROPIC_DEFAULT_HAIKU_MODEL": "deepseek-v4-flash"
}
```

---

### Step 6 — Start the proxy

```bash
routatic-proxy serve -b
routatic-proxy status
```

Should say `Server is running`.

Optional — start when you log in:

```bash
routatic-proxy autostart enable
```

---

### Step 7 — Verify (free, no tokens)

Only checks the proxy on your PC. Does **not** call OpenCode or spend credits:

```bash
curl http://127.0.0.1:3456/health
```

Look for `"status":"ok"`.

Or:

```powershell
.\scripts\check.ps1
```

```bash
bash scripts/check.sh
```

---

### Step 8 — Run Claude Code

```bash
claude
```

---

# Option B — Setup script (recommended)

Run the script. It asks **two things** at the start:

1. **Go or Zen** — picks the right proxy template  
2. **Auto or Guided** — how much hand-holding you want  

**Auto** runs all steps without asking (install routatic-proxy, install `claude`, copy configs, start proxy, enable autostart). If something is missing (Scoop, Node, etc.), it stops and tells you what to install — then re-run the script.

**Guided** does the **same steps** but asks before each one:

- **y** or **Enter** = yes, go ahead  
- **n** = no, skip (install steps fail if you say no)

The script saves your choices to `.env` in the repo folder (gitignored):

```
OPENCODE_PLAN=go
OPENCODE_API_KEY=sk-your-key-here
```

Use `OPENCODE_PLAN=zen` if you only have Zen credits. Re-run the script to change plan or refresh configs. Old `.env` files with `OPENCODE_GO_API_KEY` still work (treated as Go).

**Windows:**

```powershell
cd OPENCODE_CLAUDE_CLI
.\scripts\setup.ps1
```

**Git Bash / Mac / Linux:**

```bash
cd OPENCODE_CLAUDE_CLI
bash scripts/setup.sh
```

At the prompts:

```
Which OpenCode plan?
  1) Go  — $5/mo subscription
  2) Zen — pay-as-you-go credits

Setup style:
  1) Auto    — runs all steps automatically
  2) Guided  — same steps, asks y/Enter=yes or n=no before each one
```

Then run: `claude`

---

## Go vs Zen — quick check

If setup works but requests fail (billing error, model not found, 401):

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| You have **Go** but used Zen template | Wrong endpoint | Re-copy `routatic-proxy.config.json` or re-run script, pick **1) Go** |
| You have **Zen only** but used Go template | Wrong endpoint | Re-copy `routatic-proxy.config.zen.json` or re-run script, pick **2) Zen** |
| Not sure which plan | Check [opencode.ai](https://opencode.ai) billing | Go = $5/mo subscription; Zen = credit balance |

In `config.json`, Go configs use `"provider": "opencode-go"` and Zen configs use `"provider": "opencode-zen"`.

---

## Change models

Edit `~/.config/routatic-proxy/config.json`:

- `models.default.model_id` — main model for most chat  
- `models.complex.model_id` — harder tasks (refactors, architecture)  
- `model_overrides` — map Claude model names to OpenCode models  

List models available on your plan:

```bash
routatic-proxy models
```

Popular models on Go: `deepseek-v4-flash`, `deepseek-v4-pro`, `kimi-k2.6`, `glm-5.1`, `minimax-m2.7`, `qwen3.5-plus`  
Zen has a wider catalog (including some free-tier models) — run `routatic-proxy models` to see yours.

---

## Troubleshooting

| Problem | What to do |
|---------|------------|
| `scoop: command not found` | Install Scoop (see above) or use GitHub releases |
| Where is `config.json`? | Copy from `templates/routatic-proxy.config.json` (Go) or `routatic-proxy.config.zen.json` (Zen) |
| API errors after setup | Wrong plan template — see **Go vs Zen — quick check** above |
| `Connection refused` on 3456 | Run `routatic-proxy serve -b` |
| `validate` fails on `${ROUTATIC_PROXY_API_KEY}` | Put your real key in the file |
| Claude still uses Anthropic | `ANTHROPIC_BASE_URL` must be `http://127.0.0.1:3456` |
| `routing failed` | Use `max_tokens` ≥ 256 for reasoning models in config |

Logs: `%USERPROFILE%\.config\routatic-proxy\routatic-proxy.log` (Windows) or `~/.config/routatic-proxy/routatic-proxy.log`  
Stop proxy: `routatic-proxy stop`

---

## Back to the short guide

When you are comfortable, use [README.md](README.md) for the quick reference.

---

## Contact

Questions or issues? Reach out on [LinkedIn](https://www.linkedin.com/in/abdullahmiraz/).
