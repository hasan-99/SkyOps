<#
.SYNOPSIS
  Installs the SkyOps framework into the user's Claude Code config (~/.claude).

.DESCRIPTION
  Copies the framework's commands, skills, agents, and hook scripts from this
  repo into ~/.claude so Claude Code can load and run them.

  This machine's ~/.claude loads sky-* skills as flat files under
  ~/.claude/commands (specialist lanes have user-invocable: false and surface
  as skills). To match that proven layout, skills are installed flattened as
  ~/.claude/commands/<name>.md. The repo keeps the clean commands/ + skills/
  split so it also works as a Claude Code plugin.

  Safe and idempotent: re-running overwrites installed files with the repo
  version. It never touches ~/.claude/settings.json, secrets, or hooks wiring.

.PARAMETER DryRun
  Show what would be copied without writing anything.

.EXAMPLE
  pwsh ./install.ps1
  pwsh ./install.ps1 -DryRun
#>
[CmdletBinding()]
param(
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

$RepoRoot = $PSScriptRoot
$ClaudeHome = Join-Path $env:USERPROFILE '.claude'
$CmdDst = Join-Path $ClaudeHome 'commands'
$AgentDst = Join-Path $ClaudeHome 'agents'
$BinDst = Join-Path $ClaudeHome 'bin'

Write-Host "SkyOps installer" -ForegroundColor Cyan
Write-Host "  source: $RepoRoot"
Write-Host "  target: $ClaudeHome"
if ($DryRun) { Write-Host "  mode:   DRY RUN (no changes)" -ForegroundColor Yellow }
Write-Host ""

function Copy-One($src, $dst) {
    if ($DryRun) {
        Write-Host "  would copy -> $dst"
        return
    }
    $dstDir = Split-Path -Parent $dst
    if (-not (Test-Path $dstDir)) { New-Item -ItemType Directory -Force -Path $dstDir | Out-Null }
    Copy-Item -Path $src -Destination $dst -Force
    Write-Host "  $dst"
}

# 1. Commands -> ~/.claude/commands/<name>.md
Write-Host "Commands:" -ForegroundColor Green
Get-ChildItem -Path (Join-Path $RepoRoot 'commands') -Filter '*.md' -File | ForEach-Object {
    Copy-One $_.FullName (Join-Path $CmdDst $_.Name)
}

# 2. Skills -> flattened to ~/.claude/commands/<name>.md
Write-Host "Skills (flattened into commands):" -ForegroundColor Green
Get-ChildItem -Path (Join-Path $RepoRoot 'skills') -Directory | ForEach-Object {
    $skill = Join-Path $_.FullName 'SKILL.md'
    if (Test-Path $skill) {
        Copy-One $skill (Join-Path $CmdDst ("{0}.md" -f $_.Name))
    }
}

# 3. Agents -> ~/.claude/agents/<name>.md
Write-Host "Agents:" -ForegroundColor Green
Get-ChildItem -Path (Join-Path $RepoRoot 'agents') -Filter '*.md' -File | ForEach-Object {
    Copy-One $_.FullName (Join-Path $AgentDst $_.Name)
}

# 4. Hook scripts -> ~/.claude/bin/<name>.js and <name>.sh
#    Copies the script only. The settings.json wiring is intentionally NOT touched
#    (see note below) — the installer never edits settings.json / secrets / hooks wiring.
#
#    Both extensions ship. Where a .sh port exists, wire THAT one: node costs
#    ~9.3s per spawn on a Defender-scanned Windows box against ~1.2s for bash
#    (measured), which matters enormously for hooks that fire on every prompt or
#    every edit. The .js stays the portable reference implementation.
Write-Host "Hook scripts:" -ForegroundColor Green
$hooksDir = Join-Path $RepoRoot 'hooks'
if (Test-Path $hooksDir) {
    Get-ChildItem -Path $hooksDir -File | Where-Object { $_.Extension -in '.js', '.sh' } | ForEach-Object {
        Copy-One $_.FullName (Join-Path $BinDst $_.Name)
    }
} else {
    Write-Host "  (no hooks/ in repo)"
}

# 4b. Utility scripts -> ~/.claude/bin/ (not hooks; invoked by commands, e.g. sky-lint)
$scriptsDir = Join-Path $RepoRoot 'scripts'
if (Test-Path $scriptsDir) {
    Write-Host "Scripts:" -ForegroundColor Green
    Get-ChildItem -Path $scriptsDir -File | Where-Object { $_.Extension -in '.js', '.sh' } | ForEach-Object {
        Copy-One $_.FullName (Join-Path $BinDst $_.Name)
    }
}

# 5. Clean stale artifacts
Write-Host "Cleanup:" -ForegroundColor Green
$bak = Join-Path $CmdDst 'sky-task.md.bak'
if (Test-Path $bak) {
    if ($DryRun) { Write-Host "  would remove -> $bak" }
    else { Remove-Item $bak -Force; Write-Host "  removed $bak" }
} else {
    Write-Host "  (nothing to clean)"
}

Write-Host ""
Write-Host "Done. Restart Claude Code (or reload) to pick up changes." -ForegroundColor Cyan

# Hook wiring reminder (the installer never edits settings.json).
$nudge = Join-Path $BinDst 'sky-test-nudge.js'
if (Test-Path $nudge) {
    Write-Host ""
    Write-Host "Hook wiring (one-time, manual):" -ForegroundColor Yellow
    Write-Host "  sky-test-nudge.js is installed but not wired. To auto-nudge /sky-test after"
    Write-Host "  C# source edits in CS_Datafactory_v2, add this PostToolUse hook to"
    Write-Host '  ~/.claude/settings.json (merge into the existing "hooks" object):'
    Write-Host ''
    Write-Host '    "PostToolUse": [' -ForegroundColor DarkGray
    Write-Host '      { "matcher": "Edit|Write",' -ForegroundColor DarkGray
    Write-Host '        "hooks": [ { "type": "command",' -ForegroundColor DarkGray
    Write-Host '          "command": "node \"%USERPROFILE%\\.claude\\bin\\sky-test-nudge.js\"",' -ForegroundColor DarkGray
    Write-Host '          "statusMessage": "sky-test coverage check" } ] }' -ForegroundColor DarkGray
    Write-Host '    ]' -ForegroundColor DarkGray
    Write-Host "  (Use your real home path in the command; %USERPROFILE% is shown for reference.)"
}

$recall = Join-Path $BinDst 'knowledge-recall.sh'
if (Test-Path $recall) {
    Write-Host ""
    Write-Host "Hook wiring (one-time, manual):" -ForegroundColor Yellow
    Write-Host "  knowledge-recall.sh is installed but not wired. It makes /sky-learn lessons"
    Write-Host "  surface automatically instead of depending on the model calling /sky-recall."
    Write-Host '  Add this UserPromptSubmit hook to ~/.claude/settings.json:'
    Write-Host ''
    Write-Host '    "UserPromptSubmit": [' -ForegroundColor DarkGray
    Write-Host '      { "hooks": [ { "type": "command",' -ForegroundColor DarkGray
    Write-Host '          "command": "\"C:\\Program Files\\Git\\usr\\bin\\bash.exe\" \"%USERPROFILE%/.claude/bin/knowledge-recall.sh\"",' -ForegroundColor DarkGray
    Write-Host '          "timeout": 10 } ] }' -ForegroundColor DarkGray
    Write-Host '    ]' -ForegroundColor DarkGray
    Write-Host "  (Use your real home path; %USERPROFILE% is shown for reference.)"
    Write-Host "  Wire the .sh, not the .js — this fires on every prompt, and node costs ~9.3s"
    Write-Host "  per spawn here against ~1.2s for bash. Use the .js only where bash is absent."
    Write-Host "  The store lives at ~/.claude/skyops-knowledge (machine-local, never committed)."
    Write-Host "  It stays silent until a lesson strongly matches the prompt."
}
