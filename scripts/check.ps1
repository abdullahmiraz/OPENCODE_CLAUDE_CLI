# Safe local checks only - no OpenCode API calls, no tokens spent.
$ErrorActionPreference = "Continue"
$RepoRoot = Split-Path $PSScriptRoot -Parent
$ProxyConfig = "$env:USERPROFILE\.config\routatic-proxy\config.json"
$ClaudeSettings = "$env:USERPROFILE\.claude\settings.json"
$Pass = 0
$Fail = 0

function Ok($msg)  { Write-Host "  OK   $msg" -ForegroundColor Green; $script:Pass++ }
function Fail($msg){ Write-Host "  FAIL $msg" -ForegroundColor Red; $script:Fail++ }

Write-Host "==> Local checks (no API / no tokens)" -ForegroundColor Cyan
Write-Host ""

Write-Host "[1] Repo templates"
try {
    Get-Content "$RepoRoot\templates\routatic-proxy.config.json" -Raw | ConvertFrom-Json | Out-Null
    Get-Content "$RepoRoot\templates\claude-settings.json" -Raw | ConvertFrom-Json | Out-Null
    Ok "templates parse as JSON"
} catch {
    Fail "templates invalid: $_"
}

Write-Host "[2] Proxy config on disk"
if (Test-Path $ProxyConfig) {
    Ok "Found $ProxyConfig"
    $raw = Get-Content $ProxyConfig -Raw
    if ($raw -match '\$\{ROUTATIC_PROXY_API_KEY\}') {
        Fail "api_key still placeholder - add your key or set ROUTATIC_PROXY_API_KEY"
    } else {
        Ok "api_key looks set (not placeholder)"
    }
} else {
    Fail "Missing $ProxyConfig - copy from templates\routatic-proxy.config.json"
}

Write-Host "[3] routatic-proxy validate"
if (Get-Command routatic-proxy -ErrorAction SilentlyContinue) {
    routatic-proxy validate 2>$null
    if ($LASTEXITCODE -eq 0) { Ok "routatic-proxy validate" } else { Fail "routatic-proxy validate failed" }
} else {
    Fail "routatic-proxy not installed"
}

Write-Host "[4] Claude Code settings"
if (Test-Path $ClaudeSettings) {
    if ((Get-Content $ClaudeSettings -Raw) -match '127\.0\.0\.1:3456') {
        Ok "ANTHROPIC_BASE_URL points to local proxy"
    } else {
        Fail "settings.json missing http://127.0.0.1:3456"
    }
} else {
    Fail "Missing $ClaudeSettings"
}

Write-Host "[5] Proxy running (/health - no tokens)"
try {
    Invoke-RestMethod -Uri 'http://127.0.0.1:3456/health' -TimeoutSec 3 | Out-Null
    Ok "Proxy responding on :3456"
} catch {
    Fail "Proxy not running - run: routatic-proxy serve -b"
}

Write-Host ""
$summary = "Result: {0} passed, {1} failed" -f $Pass, $Fail
Write-Host $summary
if ($Fail -gt 0) { exit 1 }
