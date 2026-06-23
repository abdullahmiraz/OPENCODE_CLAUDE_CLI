# One-command setup: OpenCode Go + routatic-proxy + Claude Code CLI (Windows PowerShell)
$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path $PSScriptRoot -Parent

$ClaudeDir  = "$env:USERPROFILE\.claude"
$ProxyDir   = "$env:USERPROFILE\.config\routatic-proxy"
$EnvFile    = Join-Path $RepoRoot ".env"

Write-Host "==> OpenCode Go + Claude Code setup" -ForegroundColor Cyan
Write-Host ""

# Step 1: API key
$ApiKey = $null
if (Test-Path $EnvFile) {
    Get-Content $EnvFile | ForEach-Object {
        if ($_ -match '^OPENCODE_GO_API_KEY=(.+)$') { $ApiKey = $Matches[1].Trim() }
    }
}
if (-not $ApiKey) {
    Write-Host "Step 1: Enter your OpenCode Go API key"
    Write-Host "  (from https://opencode.ai -> Zen -> Go -> API key)"
    $Secure = Read-Host "API key" -AsSecureString
    $ApiKey = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [Runtime.InteropServices.Marshal]::SecureStringToBSTR($Secure))
    if (-not $ApiKey) { throw "API key is required." }
    "OPENCODE_GO_API_KEY=$ApiKey" | Set-Content $EnvFile -Encoding UTF8
    Write-Host "  Saved to $EnvFile (gitignored)"
} else {
    Write-Host "Step 1: API key found in .env"
}
$env:ROUTATIC_PROXY_API_KEY = $ApiKey
Write-Host ""

# Step 2: Install routatic-proxy
Write-Host "Step 2: Install routatic-proxy"
if (Get-Command routatic-proxy -ErrorAction SilentlyContinue) {
    Write-Host "  Already installed"
} elseif (Get-Command scoop -ErrorAction SilentlyContinue) {
    scoop bucket add routatic https://github.com/routatic/scoop-bucket 2>$null
    scoop install routatic-proxy
} else {
    throw "Install Scoop first, or install manually: https://github.com/routatic/proxy"
}
Write-Host ""

# Step 3: Install Claude Code CLI
Write-Host "Step 3: Install Claude Code CLI"
if (Get-Command claude -ErrorAction SilentlyContinue) {
    Write-Host "  Already installed"
} else {
    npm install -g @anthropic-ai/claude-code
}
Write-Host ""

# Step 4: Proxy config
Write-Host "Step 4: Write routatic-proxy config"
New-Item -ItemType Directory -Force -Path $ProxyDir | Out-Null
Copy-Item "$RepoRoot\templates\routatic-proxy.config.json" "$ProxyDir\config.json" -Force
Write-Host "  -> $ProxyDir\config.json"
Write-Host ""

# Step 5: Claude Code settings
Write-Host "Step 5: Merge Claude Code settings"
New-Item -ItemType Directory -Force -Path $ClaudeDir | Out-Null
$Settings = "$ClaudeDir\settings.json"
$Template = "$RepoRoot\templates\claude-settings.json"

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
Write-Host "  -> $Settings"
Write-Host ""

# Step 6: Start proxy
Write-Host "Step 6: Start routatic-proxy"
$env:ROUTATIC_PROXY_API_KEY = $ApiKey
routatic-proxy stop 2>$null
routatic-proxy serve -b
Start-Sleep -Seconds 2
routatic-proxy status
Write-Host ""

# Step 7: Autostart
Write-Host "Step 7: Enable autostart on login"
routatic-proxy autostart enable 2>$null
Write-Host ""

# Step 8: Verify
Write-Host "Step 8: Verify"
$body = '{"model":"deepseek-v4-flash","max_tokens":256,"messages":[{"role":"user","content":"Reply with exactly: ok"}]}'
try {
    $r = Invoke-RestMethod -Uri "http://127.0.0.1:3456/v1/messages" -Method Post `
        -Headers @{ Authorization = "Bearer unused"; "anthropic-version" = "2023-06-01" } `
        -ContentType "application/json" -Body $body
    Write-Host "  Proxy OK" -ForegroundColor Green
} catch {
    Write-Host "  Proxy test failed. Check: $ProxyDir\routatic-proxy.log" -ForegroundColor Red
    throw
}
Write-Host ""
Write-Host "Done. Run: claude" -ForegroundColor Green
Write-Host "Logs:  $ProxyDir\routatic-proxy.log"
Write-Host "Stop:  routatic-proxy stop"
