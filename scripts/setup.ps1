# Guided setup - pauses and asks before each step.
$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path $PSScriptRoot -Parent
$ClaudeDir  = "$env:USERPROFILE\.claude"
$ProxyDir   = "$env:USERPROFILE\.config\routatic-proxy"
$EnvFile    = Join-Path $RepoRoot ".env"

function Pause-Step {
    Write-Host ""
    Read-Host "Press Enter to continue (or Ctrl+C to stop)"
    Write-Host ""
}

function Confirm-Step($msg) {
    $ans = Read-Host "$msg [y/N]"
    return ($ans -eq 'y' -or $ans -eq 'Y' -or $ans -eq 'yes')
}

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  OpenCode Go + Claude Code - guided setup"
Write-Host "=========================================="
Write-Host ""
Write-Host "This script stops before each action."
Write-Host "Paths on your PC:"
Write-Host "  Proxy config  -> $ProxyDir\config.json"
Write-Host "  Claude config -> $ClaudeDir\settings.json"
Write-Host "  Templates from -> $RepoRoot\templates\"
Pause-Step

Write-Host "STEP 1/8 - OpenCode Go API key"
Write-Host "  Get it from: https://opencode.ai -> Zen -> Go -> API key"
Write-Host "  Saved to: $EnvFile (gitignored)"
$ApiKey = $null
if (Test-Path $EnvFile) {
    Get-Content $EnvFile | ForEach-Object {
        if ($_ -match '^OPENCODE_GO_API_KEY=(.+)$') { $ApiKey = $Matches[1].Trim() }
    }
}
if (-not $ApiKey) {
    $Secure = Read-Host "  Paste your API key" -AsSecureString
    $ApiKey = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [Runtime.InteropServices.Marshal]::SecureStringToBSTR($Secure))
    if (-not $ApiKey) { throw "Key required." }
    "OPENCODE_GO_API_KEY=$ApiKey" | Set-Content $EnvFile -Encoding UTF8
    Write-Host "  Saved."
} else {
    Write-Host "  Using key from existing .env"
}
$env:ROUTATIC_PROXY_API_KEY = $ApiKey
Pause-Step

Write-Host "STEP 2/8 - Install routatic-proxy"
Write-Host "  Scoop = Windows package installer (see README -> What is Scoop?)"
if (Get-Command routatic-proxy -ErrorAction SilentlyContinue) {
    Write-Host "  Already installed."
} elseif (Confirm-Step "  Install routatic-proxy via Scoop?") {
    if (Get-Command scoop -ErrorAction SilentlyContinue) {
        scoop bucket add routatic https://github.com/routatic/scoop-bucket 2>$null
        scoop install routatic-proxy
    } else {
        Write-Host "  Scoop not found. Install from https://scoop.sh then re-run."
        exit 1
    }
} else {
    Write-Host "  Skipped - install manually."
    exit 1
}
Pause-Step

Write-Host "STEP 3/8 - Install Claude Code CLI"
if (Get-Command claude -ErrorAction SilentlyContinue) {
    Write-Host "  Already installed."
} elseif (Confirm-Step "  Run: npm install -g @anthropic-ai/claude-code ?") {
    npm install -g @anthropic-ai/claude-code
} else {
    Write-Host "  Skipped."
    exit 1
}
Pause-Step

Write-Host "STEP 4/8 - Copy proxy config"
Write-Host "  FROM: $RepoRoot\templates\routatic-proxy.config.json"
Write-Host "  TO:   $ProxyDir\config.json"
if (Confirm-Step "  Copy template and insert your API key?") {
    New-Item -ItemType Directory -Force -Path $ProxyDir | Out-Null
    $content = Get-Content "$RepoRoot\templates\routatic-proxy.config.json" -Raw
    $content = $content.Replace('${ROUTATIC_PROXY_API_KEY}', $ApiKey)
    $content | Set-Content "$ProxyDir\config.json" -Encoding UTF8 -NoNewline
    Write-Host "  Done."
} else {
    Write-Host "  Skipped - copy template yourself (README Path A Step 4)."
}
Pause-Step

Write-Host "STEP 5/8 - Claude Code settings"
Write-Host "  FROM: $RepoRoot\templates\claude-settings.json"
Write-Host "  TO:   $ClaudeDir\settings.json"
$Settings = "$ClaudeDir\settings.json"
$Template = "$RepoRoot\templates\claude-settings.json"
if (Confirm-Step "  Copy or merge Claude settings?") {
    New-Item -ItemType Directory -Force -Path $ClaudeDir | Out-Null
    if (Test-Path $Settings) {
        $Backup = "$Settings.backup.$(Get-Date -UFormat %s)"
        Copy-Item $Settings $Backup
        Write-Host "  Backed up to $Backup"
        $cur = Get-Content $Settings -Raw | ConvertFrom-Json
        $tpl = Get-Content $Template -Raw | ConvertFrom-Json
        $merged = @{}
        if ($cur.env) { $cur.env.PSObject.Properties | ForEach-Object { $merged[$_.Name] = $_.Value } }
        $tpl.env.PSObject.Properties | ForEach-Object { $merged[$_.Name] = $_.Value }
        $cur | Add-Member -NotePropertyName env -NotePropertyValue $merged -Force
        $cur | ConvertTo-Json -Depth 10 | Set-Content $Settings -Encoding UTF8
    } else {
        Copy-Item $Template $Settings
    }
    Write-Host "  Done."
} else {
    Write-Host "  Skipped."
}
Pause-Step

Write-Host "STEP 6/8 - Start routatic-proxy"
if (Confirm-Step "  Start proxy on http://127.0.0.1:3456 ?") {
    $env:ROUTATIC_PROXY_API_KEY = $ApiKey
    routatic-proxy stop 2>$null
    routatic-proxy serve -b
    Start-Sleep -Seconds 2
    routatic-proxy status
} else {
    Write-Host "  Skipped - run later: routatic-proxy serve -b"
}
Pause-Step

Write-Host "STEP 7/8 - Autostart on login (optional)"
if (Confirm-Step "  Enable autostart?") {
    routatic-proxy autostart enable 2>$null
} else {
    Write-Host "  Skipped."
}
Pause-Step

Write-Host "STEP 8/8 - Verify (free checks only, no tokens)"
& "$RepoRoot\scripts\check.ps1"
Write-Host ""
Write-Host "==========================================" -ForegroundColor Green
Write-Host "  Setup complete. Run:  claude"
Write-Host "  Re-check anytime:    .\scripts\check.ps1"
Write-Host "=========================================="
