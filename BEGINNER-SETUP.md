# Beginner setup guide

**This guide is for new or inexperienced users.**  
If you already know your way around the terminal, use the short [README.md](README.md) instead.

It explains:

- What `~/.config/routatic-proxy/config.json` is and where it comes from
- What Scoop is and how to install it (Windows)
- Two ways to set up: **guided** (yes/no before each step) or **auto** (runs everything)
- How to verify without spending API credits

---

## What you are building

```
Claude Code  →  routatic-proxy (your PC, port 3456)  →  OpenCode Go
```

Claude Code thinks it talks to Anthropic. The proxy translates requests to OpenCode Go models.

---

## What you need first

1. [OpenCode Go](https://opencode.ai/docs/go/) subscription + API key  
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
OPENCODE_CLAUDE_CLI/templates/routatic-proxy.config.json   ← copy this
OPENCODE_CLAUDE_CLI/templates/claude-settings.json         ← copy or merge this
```

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

### Step 1 — Get your OpenCode Go API key

1. Open [opencode.ai](https://opencode.ai)  
2. Sign in → **Zen** → subscribe to **Go**  
3. Copy your API key (`sk-...`)  
4. Never commit it to git or share it publicly

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

From the folder where you cloned this repo:

**Git Bash / Mac / Linux:**

```bash
cd OPENCODE_CLAUDE_CLI
mkdir -p ~/.config/routatic-proxy
cp templates/routatic-proxy.config.json ~/.config/routatic-proxy/config.json
```

**Windows PowerShell:**

```powershell
cd OPENCODE_CLAUDE_CLI
New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\.config\routatic-proxy"
Copy-Item templates\routatic-proxy.config.json "$env:USERPROFILE\.config\routatic-proxy\config.json"
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

# Option B — Setup script

Run the script and pick **1 (auto)** or **2 (guided)** at the start.

**Auto** runs all steps without asking (install routatic-proxy, install `claude`, copy configs, start proxy, enable autostart). If something is missing (Scoop, Node, etc.), it stops and tells you what to install — then re-run the script.

**Guided** does the **same steps** but asks before each one:

- **y** or **Enter** = yes, go ahead  
- **n** = no, skip (install steps fail if you say no)

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

At the prompt:

```
Choose one:
  1) Auto    — runs all steps automatically
  2) Guided  — same steps, asks y/Enter=yes or n=no before each one

Enter 1 or 2:
```

Then run: `claude`

---

## Troubleshooting

| Problem | What to do |
|---------|------------|
| `scoop: command not found` | Install Scoop (see above) or use GitHub releases |
| Where is `config.json`? | Copy from `templates/routatic-proxy.config.json` in this repo |
| `Connection refused` on 3456 | Run `routatic-proxy serve -b` |
| `validate` fails on `${ROUTATIC_PROXY_API_KEY}` | Put your real key in the file |
| Claude still uses Anthropic | `ANTHROPIC_BASE_URL` must be `http://127.0.0.1:3456` |

Logs: `%USERPROFILE%\.config\routatic-proxy\routatic-proxy.log` (Windows) or `~/.config/routatic-proxy/routatic-proxy.log`  
Stop proxy: `routatic-proxy stop`

---

## Back to the short guide

When you are comfortable, use [README.md](README.md) for the quick reference.

---

## Contact

Questions or issues? Reach out on [LinkedIn](https://www.linkedin.com/in/abdullahmiraz/).
