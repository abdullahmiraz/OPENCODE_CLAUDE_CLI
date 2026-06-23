# OpenCode Go + Claude Code setup — auto (fast) or guided (yes/no per step).
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

function Pause-Step {
    Write-Host ""
    Read-Host "Press Enter to continue (or Ctrl+C to stop)"
    Write-Host ""
}

function Confirm-Step($msg) {
    $ans = Read-Host "$msg [y/N]"
    return ($ans -eq 'y' -or $ans -eq 'Y' -or $ans -eq 'yes')
}

function Stop-Blocked($msg) {
    Write-Host ""
    Write-Host "BLOCKED: $msg" -ForegroundColor Red
    Write-Host "Fix the issue above, then run this script again." -ForegroundColor Yellow
    exit 1
}

function Choose-Mode {
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host "  OpenCode Go + Claude Code setup"
    Write-Host "=========================================="
    Write-Host ""
    Write-Host "Choose one:"
    Write-Host "  1) Auto    - runs all steps automatically"
    Write-Host "  2) Guided  - same steps, asks yes/no before each one"
    Write-Host ""
    $choice = Read-Host "Enter 1 or 2"
    switch ($choice) {
        { $_ -in '1','auto','Auto','AUTO' } { return 'auto' }
        { $_ -in '2','guided','Guided','GUIDED','manual','Manual','MANUAL' } { return 'guided' }
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
        Write-Step "STEP 1/8 - API key"
        Write-Info "Get it from: https://opencode.ai -> Zen -> Go"
        $secure = Read-Host "  Paste your API key" -AsSecureString
        $key = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
            [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure))
        if (-not $key) { Stop-Blocked "API key is required." }
        "OPENCODE_GO_API_KEY=$key" | Set-Content $EnvFile -Encoding UTF8
        Write-Info "Saved to $EnvFile"
    } else {
        Write-Step "STEP 1/8 - API key"
        Write-Info "Using key from $EnvFile"
    }
    $env:ROUTATIC_PROXY_API_KEY = $key
    return $key
}

function Install-Routatic {
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
"@
}

function Install-ClaudeCli {
    npm install -g @anthropic-ai/claude-code
}

function Write-ProxyConfig($ApiKey) {
    New-Item -ItemType Directory -Force -Path $ProxyDir | Out-Null
    $content = Get-Content "$RepoRoot\templates\routatic-proxy.config.json" -Raw
    $content = $content.Replace('${ROUTATIC_PROXY_API_KEY}', $ApiKey)
    $content | Set-Content "$ProxyDir\config.json" -Encoding UTF8 -NoNewline
    Write-Info "Done."
}

function Write-ClaudeSettings {
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
    $env:ROUTATIC_PROXY_API_KEY = $ApiKey
    routatic-proxy stop 2>$null
    routatic-proxy serve -b
    Start-Sleep -Seconds 2
    routatic-proxy status
}

function Enable-Autostart {
    routatic-proxy autostart enable 2>$null
    if ($LASTEXITCODE -ne 0) { Write-Info "Autostart not supported (start manually after reboot)." }
}

function Verify-Setup {
    & "$RepoRoot\scripts\check.ps1"
}

function Print-Done($label) {
    Write-Host ""
    Write-Host "==========================================" -ForegroundColor Green
    Write-Host "  $label setup complete. Run:  claude"
    Write-Host "  After reboot:             claude"
    Write-Host "    (if autostart worked)   or: routatic-proxy serve -b"
    Write-Host "  Re-check:                 .\scripts\check.ps1"
    Write-Host "=========================================="
}

function Run-Auto {
    $apiKey = Get-ApiKey
    Write-Step "STEP 2/8 - Install routatic-proxy"
    if (Get-Command routatic-proxy -ErrorAction SilentlyContinue) {
        Write-Info "Already installed."
    } else { Install-Routatic }
    Write-Step "STEP 3/8 - Install Claude Code CLI"
    if (Get-Command claude -ErrorAction SilentlyContinue) {
        Write-Info "Already installed."
    } elseif (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
        Stop-Blocked "npm not found. Install Node.js from https://nodejs.org then re-run."
    } else { Install-ClaudeCli }
    Write-Step "STEP 4/8 - Write proxy config -> $ProxyDir\config.json"
    Write-ProxyConfig $apiKey
    Write-Step "STEP 5/8 - Write Claude settings -> $ClaudeDir\settings.json"
    Write-ClaudeSettings
    Write-Step "STEP 6/8 - Start routatic-proxy"
    Start-Proxy $apiKey
    Write-Step "STEP 7/8 - Enable autostart on login"
    Enable-Autostart
    Write-Step "STEP 8/8 - Verify"
    Verify-Setup
    Print-Done "Auto"
}

function Run-Guided {
    Write-Host ""
    Write-Host "Guided setup - you confirm each step before it runs."
    Write-Host "Paths:"
    Write-Host "  Proxy config  -> $ProxyDir\config.json"
    Write-Host "  Claude config -> $ClaudeDir\settings.json"
    Pause-Step

    $apiKey = Get-ApiKey
    Pause-Step

    Write-Step "STEP 2/8 - Install routatic-proxy"
    if (Get-Command routatic-proxy -ErrorAction SilentlyContinue) {
        Write-Info "Already installed."
    } elseif (Confirm-Step "  Install routatic-proxy via Scoop?") {
        Install-Routatic
    } else {
        Stop-Blocked "Install routatic-proxy manually, then re-run."
    }
    Pause-Step

    Write-Step "STEP 3/8 - Install Claude Code CLI"
    if (Get-Command claude -ErrorAction SilentlyContinue) {
        Write-Info "Already installed."
    } elseif (Confirm-Step "  Run: npm install -g @anthropic-ai/claude-code ?") {
        if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
            Stop-Blocked "npm not found. Install Node.js from https://nodejs.org then re-run."
        }
        Install-ClaudeCli
    } else {
        Stop-Blocked "Install claude manually, then re-run."
    }
    Pause-Step

    Write-Step "STEP 4/8 - Copy proxy config"
    Write-Info "FROM: $RepoRoot\templates\routatic-proxy.config.json"
    Write-Info "TO:   $ProxyDir\config.json"
    if (Confirm-Step "  Copy template and insert your API key?") {
        Write-ProxyConfig $apiKey
    } else {
        Write-Info "Skipped - copy template yourself (see README)."
    }
    Pause-Step

    Write-Step "STEP 5/8 - Claude Code settings"
    Write-Info "FROM: $RepoRoot\templates\claude-settings.json"
    Write-Info "TO:   $ClaudeDir\settings.json"
    if (Confirm-Step "  Copy or merge Claude settings?") {
        Write-ClaudeSettings
    } else {
        Write-Info "Skipped."
    }
    Pause-Step

    Write-Step "STEP 6/8 - Start routatic-proxy"
    if (Confirm-Step "  Start proxy on http://127.0.0.1:3456 ?") {
        Start-Proxy $apiKey
    } else {
        Write-Info "Skipped - run later: routatic-proxy serve -b"
    }
    Pause-Step

    Write-Step "STEP 7/8 - Autostart on login (optional)"
    if (Confirm-Step "  Enable autostart?") {
        Enable-Autostart
    } else {
        Write-Info "Skipped."
    }
    Pause-Step

    Write-Step "STEP 8/8 - Verify"
    Verify-Setup
    Print-Done "Guided"
}

$mode = Choose-Mode
if ($mode -eq 'guided') {
    Run-Guided
} else {
    Run-Auto
}
