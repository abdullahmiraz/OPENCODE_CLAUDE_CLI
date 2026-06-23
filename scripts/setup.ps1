# OpenCode Go + Claude Code setup — choose auto or manual at start.
$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path $PSScriptRoot -Parent
$ClaudeDir  = "$env:USERPROFILE\.claude"
$ProxyDir   = "$env:USERPROFILE\.config\routatic-proxy"
$EnvFile    = Join-Path $RepoRoot ".env"

function Write-Step($msg) {
    Write-Host ""
    Write-Host "==> $msg" -ForegroundColor Cyan
}

function Write-Info($msg) { Write-Host "  $msg" }

function Stop-Blocked($msg) {
    Write-Host ""
    Write-Host "BLOCKED: $msg" -ForegroundColor Red
    Write-Host "Fix the issue above, then run this script again." -ForegroundColor Yellow
    exit 1
}

function Show-Manual {
    @"

MANUAL SETUP — do these steps yourself, then run: claude

  1. Get API key from https://opencode.ai (Zen -> Go)

  2. Install routatic-proxy
       scoop bucket add routatic https://github.com/routatic/scoop-bucket
       scoop install routatic-proxy

  3. Install Claude Code CLI
       npm install -g @anthropic-ai/claude-code

  4. Copy proxy config
       New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\.config\routatic-proxy"
       Copy-Item templates\routatic-proxy.config.json "$env:USERPROFILE\.config\routatic-proxy\config.json"
       Edit that file and set your api_key

  5. Copy Claude settings
       New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\.claude"
       Copy-Item templates\claude-settings.json "$env:USERPROFILE\.claude\settings.json"

  6. Start proxy
       routatic-proxy serve -b

  7. Verify (no tokens)
       .\scripts\check.ps1

  8. Run
       claude

Full details: BEGINNER-SETUP.md or README.md

"@
}

function Choose-Mode {
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host "  OpenCode Go + Claude Code setup"
    Write-Host "=========================================="
    Write-Host ""
    Write-Host "Choose one:"
    Write-Host "  1) Auto   - script installs and configures everything"
    Write-Host "  2) Manual - print steps, you do them yourself"
    Write-Host ""
    $choice = Read-Host "Enter 1 or 2"
    switch ($choice) {
        { $_ -in '1','auto','Auto','AUTO' } { return 'auto' }
        { $_ -in '2','manual','Manual','MANUAL' } { return 'manual' }
        default { Stop-Blocked "Invalid choice. Enter 1 or 2." }
    }
}

function Get-ApiKey {
    $key = $null
    if (Test-Path $EnvFile) {
        Get-Content $EnvFile | ForEach-Object {
            if ($_ -match '^OPENCODE_GO_API_KEY=(.+)$') { $key = $Matches[1].Trim() }
        }
    }
    if (-not $key) {
        Write-Step "API key"
        Write-Info "Get it from: https://opencode.ai -> Zen -> Go"
        $secure = Read-Host "Paste your API key" -AsSecureString
        $key = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
            [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure))
        if (-not $key) { Stop-Blocked "API key is required." }
        "OPENCODE_GO_API_KEY=$key" | Set-Content $EnvFile -Encoding UTF8
        Write-Info "Saved to $EnvFile"
    } else {
        Write-Step "API key"
        Write-Info "Using key from $EnvFile"
    }
    $env:ROUTATIC_PROXY_API_KEY = $key
    return $key
}

function Install-Routatic {
    Write-Step "Install routatic-proxy"
    if (Get-Command routatic-proxy -ErrorAction SilentlyContinue) {
        Write-Info "Already installed."
        return
    }
    if (Get-Command scoop -ErrorAction SilentlyContinue) {
        scoop bucket add routatic https://github.com/routatic/scoop-bucket 2>$null
        scoop install routatic-proxy
        return
    }
    Stop-Blocked @"
Scoop not found.
Install Scoop (one-time) in PowerShell:
  Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
  Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression
Then re-run this script.
Or download routatic-proxy from https://github.com/routatic/proxy/releases
"@
}

function Install-ClaudeCli {
    Write-Step "Install Claude Code CLI"
    if (Get-Command claude -ErrorAction SilentlyContinue) {
        Write-Info "Already installed."
        return
    }
    if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
        Stop-Blocked "npm not found. Install Node.js from https://nodejs.org then re-run this script."
    }
    npm install -g @anthropic-ai/claude-code
}

function Write-ProxyConfig($ApiKey) {
    Write-Step "Write proxy config -> $ProxyDir\config.json"
    New-Item -ItemType Directory -Force -Path $ProxyDir | Out-Null
    $content = Get-Content "$RepoRoot\templates\routatic-proxy.config.json" -Raw
    $content = $content.Replace('${ROUTATIC_PROXY_API_KEY}', $ApiKey)
    $content | Set-Content "$ProxyDir\config.json" -Encoding UTF8 -NoNewline
    Write-Info "Done."
}

function Write-ClaudeSettings {
    Write-Step "Write Claude settings -> $ClaudeDir\settings.json"
    New-Item -ItemType Directory -Force -Path $ClaudeDir | Out-Null
    $settings = "$ClaudeDir\settings.json"
    $template = "$RepoRoot\templates\claude-settings.json"
    if (Test-Path $settings) {
        $backup = "$settings.backup.$(Get-Date -UFormat %s)"
        Copy-Item $settings $backup
        Write-Info "Backed up to $backup"
        $cur = Get-Content $settings -Raw | ConvertFrom-Json
        $tpl = Get-Content $template -Raw | ConvertFrom-Json
        $merged = @{}
        if ($cur.env) { $cur.env.PSObject.Properties | ForEach-Object { $merged[$_.Name] = $_.Value } }
        $tpl.env.PSObject.Properties | ForEach-Object { $merged[$_.Name] = $_.Value }
        $cur | Add-Member -NotePropertyName env -NotePropertyValue $merged -Force
        $cur | ConvertTo-Json -Depth 10 | Set-Content $settings -Encoding UTF8
    } else {
        Copy-Item $template $settings
    }
    Write-Info "Done."
}

function Start-Proxy($ApiKey) {
    Write-Step "Start routatic-proxy on http://127.0.0.1:3456"
    $env:ROUTATIC_PROXY_API_KEY = $ApiKey
    routatic-proxy stop 2>$null
    routatic-proxy serve -b
    Start-Sleep -Seconds 2
    routatic-proxy status
}

function Enable-Autostart {
    Write-Step "Enable autostart on login"
    routatic-proxy autostart enable 2>$null
    if ($LASTEXITCODE -ne 0) { Write-Info "Autostart not supported (start manually after reboot)." }
}

function Verify-Setup {
    Write-Step "Verify (local checks only, no tokens)"
    & "$RepoRoot\scripts\check.ps1"
}

function Run-Auto {
    $apiKey = Get-ApiKey
    Install-Routatic
    Install-ClaudeCli
    Write-ProxyConfig $apiKey
    Write-ClaudeSettings
    Start-Proxy $apiKey
    Enable-Autostart
    Verify-Setup
    Write-Host ""
    Write-Host "==========================================" -ForegroundColor Green
    Write-Host "  Auto setup complete. Run:  claude"
    Write-Host "  After reboot:             claude"
    Write-Host "    (if autostart worked)   or: routatic-proxy serve -b"
    Write-Host "  Re-check:                 .\scripts\check.ps1"
    Write-Host "=========================================="
}

$mode = Choose-Mode
if ($mode -eq 'manual') {
    Show-Manual
    exit 0
}

Run-Auto
