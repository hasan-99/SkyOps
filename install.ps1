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

# Hook implementation selection (the installer never edits settings.json).
#
# The plugin manifest always wires the portable .js, so hooks work out of the box
# with no Git Bash. Where a .sh port exists AND Git Bash is present, wiring the
# .sh in settings.json is faster — measured on this machine: ~7.3s per node spawn
# against ~0.7s for bash, on a Defender-scanned box. The node side detects a
# wired .sh and stands down for that guard, so wiring both does not double-fire.
Write-Host ""
Write-Host "Hook implementation:" -ForegroundColor Green
$bashExe = @(
    $env:SKYOPS_BASH,
    'C:\Program Files\Git\bin\bash.exe',
    'C:\Program Files\Git\usr\bin\bash.exe',
    'C:\Program Files (x86)\Git\bin\bash.exe'
) | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1

if (-not $bashExe) {
    Write-Host "  Git Bash not found -> the plugin's node hooks are active. Nothing to do."
    Write-Host "  (Install Git for Windows later and re-run to get the faster bash hooks.)"
} else {
    Write-Host "  Git Bash found at $bashExe"
    Write-Host "  The node hooks already work. To use the faster bash ports, add these to"
    Write-Host '  ~/.claude/settings.json (merge into the existing "hooks" object):' -ForegroundColor Yellow
    Write-Host ''
    $shHooks = @(
        @{ Event = 'PreToolUse';       Matcher = 'Bash';       Script = 'sql-guard.sh' },
        @{ Event = 'PreToolUse';       Matcher = 'Bash';       Script = 'git-guard.sh' },
        @{ Event = 'PostToolUse';      Matcher = 'Edit|Write'; Script = 'sky-test-nudge.sh' },
        @{ Event = 'UserPromptSubmit'; Matcher = $null;        Script = 'knowledge-recall.sh' }
    )
    foreach ($h in $shHooks) {
        $target = Join-Path $BinDst $h.Script
        if (-not (Test-Path $target)) { continue }
        $m = if ($h.Matcher) { '"matcher": "' + $h.Matcher + '", ' } else { '' }
        Write-Host ("    " + $h.Event + ": { " + $m + '"hooks": [ { "type": "command",') -ForegroundColor DarkGray
        Write-Host ('      "command": "\"' + $bashExe + '\" \"' + $target + '\"", "timeout": 10 } ] }') -ForegroundColor DarkGray
    }
    Write-Host ''
    Write-Host "  dotnet-format has no .sh port, so it keeps running on node either way."
    Write-Host "  The lesson store lives at ~/.claude/skyops-knowledge (machine-local)."
}
Write-Host ""
Write-Host "  Check what is actually active at any time with:"
Write-Host "    node `"$(Join-Path $BinDst 'hook-doctor.js')`"" -ForegroundColor DarkGray
Write-Host "  It prints the winning implementation per hook and flags any double-wiring."
