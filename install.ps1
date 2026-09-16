<#
.SYNOPSIS
  Installs the SkyOps framework into the user's Claude Code config (~/.claude).

.DESCRIPTION
  Copies the framework's commands, skills, agents, bin scripts, and hook scripts
  from this repo into ~/.claude so Claude Code can load and run them, generates
  ~/.claude/CLAUDE.md from the SkyOps rule source, and reindexes the memory store.

  SkyOps is the source of truth. Everything this script writes under ~/.claude is
  generated output and will be overwritten on the next sync — edit the repo, not
  the installed copy.

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
$RefDst = Join-Path $ClaudeHome 'skyops-refs'
$WarnFile = Join-Path $ClaudeHome 'skyops-install-warnings.txt'

Write-Host "SkyOps installer" -ForegroundColor Cyan
Write-Host "  source: $RepoRoot"
Write-Host "  target: $ClaudeHome"
if ($DryRun) { Write-Host "  mode:   DRY RUN (no changes)" -ForegroundColor Yellow }
Write-Host ""

# 0. Stamp gate.
#    This runs on EVERY SessionStart. Copying ~55 files and reindexing the memory
#    store when nothing changed is pure latency. The stamp is HEAD plus a hash of
#    the working tree's dirty state, so an uncommitted edit still triggers a sync
#    (the framework is routinely run from a dirty tree) while an unchanged repo
#    costs one git call and exits.
$StampFile = Join-Path $ClaudeHome '.skyops-install-stamp'
$stamp = $null
try {
    Push-Location $RepoRoot
    $head = (& git rev-parse HEAD 2>$null)
    $dirty = (& git status --porcelain 2>$null) -join "`n"
    Pop-Location
    if ($head) {
        $sha = [System.Security.Cryptography.SHA1]::Create()
        $bytes = [System.Text.Encoding]::UTF8.GetBytes("$head|$dirty")
        $stamp = [BitConverter]::ToString($sha.ComputeHash($bytes)).Replace('-', '')
    }
} catch { $stamp = $null }

if ($stamp -and -not $DryRun -and $env:SKYOPS_FORCE -ne '1') {
    $prev = if (Test-Path $StampFile) { (Get-Content $StampFile -Raw).Trim() } else { '' }
    if ($prev -eq $stamp) {
        Write-Host "  repo unchanged since last sync - nothing to do (SKYOPS_FORCE=1 to override)" -ForegroundColor DarkGray
        if ((Test-Path $WarnFile) -and (Get-Item $WarnFile).Length -eq 0) { Remove-Item $WarnFile -Force }
        exit 0
    }
}

# Replaces the {{SKYOPS_SECRETS}} marker with the machine-local secrets file.
# The value is never echoed, and never read back into the repo.
function Expand-Secrets($text) {
    if ($text -notmatch '\{\{SKYOPS_SECRETS\}\}') { return $text }
    $secretsFile = Join-Path $ClaudeHome 'skyops-secrets.local.md'
    if (Test-Path $secretsFile) {
        Write-Host "  spliced local secrets from skyops-secrets.local.md (value not shown)"
        return $text.Replace('{{SKYOPS_SECRETS}}', [System.IO.File]::ReadAllText($secretsFile).Trim())
    }
    Write-Host "  no skyops-secrets.local.md — placeholder used"
    return $text.Replace('{{SKYOPS_SECRETS}}',
        "> Not configured on this machine. Create ``~/.claude/skyops-secrets.local.md`` with the connection details; SkyOps splices it in here and never stores it in the repo.")
}

# Strips YAML frontmatter and returns the body.
function Get-Body($path) {
    $lines = [System.IO.File]::ReadAllLines($path)
    $start = 0
    if ($lines.Count -gt 0 -and $lines[0].Trim() -eq '---') {
        for ($i = 1; $i -lt $lines.Count; $i++) {
            if ($lines[$i].Trim() -eq '---') { $start = $i + 1; break }
        }
    }
    if ($start -ge $lines.Count) { return '' }
    return ($lines[$start..($lines.Count - 1)] -join "`n").Trim()
}

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
# README.md is documentation, not an agent definition. _OUTPUT-CONTRACT.md is a
# shared fragment appended to every agent so the cap lives in one file instead of
# being restated seven times. Neither is installed as an agent.
$contractFile = Join-Path $RepoRoot 'agents\_OUTPUT-CONTRACT.md'
$contract = if (Test-Path $contractFile) { "`n`n---`n`n" + (Get-Body $contractFile) } else { '' }

Get-ChildItem -Path (Join-Path $RepoRoot 'agents') -Filter '*.md' -File |
    Where-Object { $_.Name -ne 'README.md' -and $_.Name -ne '_OUTPUT-CONTRACT.md' } | ForEach-Object {
        $text = [System.IO.File]::ReadAllText($_.FullName).TrimEnd() + $contract
        $dst = Join-Path $AgentDst $_.Name
        $old = if (Test-Path $dst) { [System.IO.File]::ReadAllText($dst) } else { '' }
        if ($old -eq $text) { Write-Host "  $($_.BaseName) (current)" }
        elseif ($DryRun) { Write-Host "  would copy -> $dst" }
        else {
            $dstDir = Split-Path -Parent $dst
            if (-not (Test-Path $dstDir)) { New-Item -ItemType Directory -Force -Path $dstDir | Out-Null }
            [System.IO.File]::WriteAllText($dst, $text, [System.Text.UTF8Encoding]::new($false))
            Write-Host "  $dst"
        }
    }

# 4. Hook scripts -> ~/.claude/bin/<name>.js
#    Copies the script only. The settings.json wiring is intentionally NOT touched
#    (see note below) — the installer never edits settings.json / secrets / hooks wiring.
Write-Host "Hook scripts:" -ForegroundColor Green
$hooksDir = Join-Path $RepoRoot 'hooks'
if (Test-Path $hooksDir) {
    Get-ChildItem -Path $hooksDir -Filter '*.js' -File | ForEach-Object {
        Copy-One $_.FullName (Join-Path $BinDst $_.Name)
    }
} else {
    Write-Host "  (no hooks/ in repo)"
}

# 5. Bin scripts -> ~/.claude/bin/<name>
#    Hook, statusline, and memory tooling. These used to live only in ~/.claude,
#    which meant the runtime copy was the only copy — they are repo-owned now.
Write-Host "Bin scripts:" -ForegroundColor Green
$binSrc = Join-Path $RepoRoot 'bin'
if (Test-Path $binSrc) {
    Get-ChildItem -Path $binSrc -File | ForEach-Object {
        Copy-One $_.FullName (Join-Path $BinDst $_.Name)
    }
} else {
    Write-Host "  (no bin/ in repo)"
}

# 5b. Reference docs -> ~/.claude/skyops-refs/
#     Material a skill needs only at one specific moment (the sky-task plan template,
#     the execution engine). Keeping it out of SKILL.md means the skill body stays
#     cheap and the heavy part is read on demand. Skills are installed flattened to a
#     single .md, so a references/ subfolder inside a skill would be silently dropped
#     - that is why these live in their own folder.
Write-Host "Reference docs:" -ForegroundColor Green
$refSrc = Join-Path $RepoRoot 'references'
if (Test-Path $refSrc) {
    Get-ChildItem -Path $refSrc -Filter '*.md' -File | ForEach-Object {
        Copy-One $_.FullName (Join-Path $RefDst $_.Name)
    }
} else {
    Write-Host "  (no references/ in repo)"
}

# 6. Rules -> ~/.claude/CLAUDE.md
#    Permanent behavioural rules live in memory/rules/*.md and are concatenated,
#    in filename order, into the always-loaded global instruction file. The
#    generated file is replaced wholesale; the previous version is backed up the
#    first time it changes. Machine-local credentials are spliced in from
#    ~/.claude/skyops-secrets.local.md and never stored in this repo.
Write-Host "Rules -> CLAUDE.md:" -ForegroundColor Green
$rulesDir = Join-Path $RepoRoot 'memory\rules'
if (Test-Path $rulesDir) {
    $ruleFiles = @(Get-ChildItem -Path $rulesDir -Filter '*.md' -File | Sort-Object Name)

    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine('<!-- Generated by SkyOps install.ps1 from memory/rules/*.md.')
    [void]$sb.AppendLine('     Do NOT edit this file by hand: the next SessionStart sync overwrites it.')
    [void]$sb.AppendLine('     Edit C:\SharedProjects\SkyOps\memory\rules\ instead. -->')
    [void]$sb.AppendLine()

    foreach ($rf in $ruleFiles) {
        [void]$sb.AppendLine((Get-Body $rf.FullName))
        [void]$sb.AppendLine()
    }

    $content = Expand-Secrets $sb.ToString()
    $claudeMd = Join-Path $ClaudeHome 'CLAUDE.md'
    $existing = if (Test-Path $claudeMd) { [System.IO.File]::ReadAllText($claudeMd) } else { '' }

    if ($existing -eq $content) {
        Write-Host "  CLAUDE.md already current ($($ruleFiles.Count) rules)"
    } elseif ($DryRun) {
        Write-Host "  would regenerate $claudeMd from $($ruleFiles.Count) rule files"
    } else {
        if ($existing) {
            $backupDir = Join-Path $ClaudeHome 'backups'
            if (-not (Test-Path $backupDir)) { New-Item -ItemType Directory -Force -Path $backupDir | Out-Null }
            $stamp = [DateTime]::Now.ToString('yyyyMMdd-HHmmss', [System.Globalization.CultureInfo]::InvariantCulture)
            Copy-Item $claudeMd (Join-Path $backupDir "CLAUDE.md.$stamp.bak") -Force
            Write-Host "  backed up previous CLAUDE.md -> backups\CLAUDE.md.$stamp.bak"
        }
        [System.IO.File]::WriteAllText($claudeMd, $content, [System.Text.UTF8Encoding]::new($false))
        Write-Host "  $claudeMd ($($ruleFiles.Count) rules)"
    }
} else {
    Write-Host "  (no memory/rules/ in repo)"
}

# 6b. On-demand rule packs -> ~/.claude/commands/<pack>.md
#     Rules that are binding but topic-specific. They stay out of the always-loaded
#     CLAUDE.md and load as skills when the matching work starts, so a session that
#     never touches Jira or a database never pays for those rules.
Write-Host "Rule packs (on-demand):" -ForegroundColor Green
$packRoot = Join-Path $RepoRoot 'memory\rules-ondemand'
if (Test-Path $packRoot) {
    Get-ChildItem -Path $packRoot -Directory | ForEach-Object {
        $packMeta = Join-Path $_.FullName 'PACK.md'
        if (-not (Test-Path $packMeta)) {
            Write-Host "  skipped $($_.Name) (no PACK.md)" -ForegroundColor DarkGray
            return
        }

        # PACK.md holds only frontmatter; the rule files supply the body.
        $meta = [System.IO.File]::ReadAllText($packMeta).Trim()
        $packName = if ($meta -match '(?m)^name:\s*(\S+)') { $Matches[1] } else { "sky-rules-$($_.Name)" }

        $ps = [System.Text.StringBuilder]::new()
        [void]$ps.AppendLine($meta)
        [void]$ps.AppendLine()
        [void]$ps.AppendLine("<!-- Generated by SkyOps install.ps1 from memory/rules-ondemand/$($_.Name)/.")
        [void]$ps.AppendLine('     Do NOT edit by hand: the next sync overwrites it. -->')
        [void]$ps.AppendLine()
        [void]$ps.AppendLine('These rules are binding. You loaded this pack because you are about to do the')
        [void]$ps.AppendLine('matching work; apply them as you go.')
        [void]$ps.AppendLine()
        [void]$ps.AppendLine('**Load once per session.** This pack is now in context and stays there for the')
        [void]$ps.AppendLine('rest of the session. Do NOT load it again on a later turn — re-invoking it adds')
        [void]$ps.AppendLine('a second full copy of these rules to the conversation and buys nothing. If you')
        [void]$ps.AppendLine('are unsure whether it is loaded, assume it is.')
        [void]$ps.AppendLine()

        Get-ChildItem -Path $_.FullName -Filter '*.md' -File |
            Where-Object { $_.Name -ne 'PACK.md' } | Sort-Object Name | ForEach-Object {
                [void]$ps.AppendLine((Get-Body $_.FullName))
                [void]$ps.AppendLine()
            }

        $packText = Expand-Secrets $ps.ToString()
        $packDst = Join-Path $CmdDst "$packName.md"
        $packOld = if (Test-Path $packDst) { [System.IO.File]::ReadAllText($packDst) } else { '' }

        if ($packOld -eq $packText) { Write-Host "  $packName (current)" }
        elseif ($DryRun) { Write-Host "  would write -> $packDst" }
        else {
            [System.IO.File]::WriteAllText($packDst, $packText, [System.Text.UTF8Encoding]::new($false))
            Write-Host "  $packDst"
        }
    }
} else {
    Write-Host "  (no memory/rules-ondemand/ in repo)"
}

# 7. Reindex the memory store.
#    Frontmatter only, no file bodies — cheap enough for every SessionStart.
#    Never fatal: a missing or ambiguous memory store must not block the install.
#    Index EVERY SkyOps-managed store, not the one the cwd happens to resolve to.
#    This hook inherits the starting session's working directory, so the store that
#    got reindexed used to depend on where Claude Code was launched from - a session
#    started under C:\SharedProjects reindexed a different store than one started in
#    the home directory, and the two drifted apart. Explicit -MemoryRoot per store
#    makes the result identical no matter who runs it.
Write-Host "Memory index:" -ForegroundColor Green
$memTool = Join-Path $BinDst 'skyops-memory.ps1'
if ((Test-Path $memTool) -and -not $DryRun) {
    $projects = Join-Path $ClaudeHome 'projects'
    $stores = @()
    if (Test-Path $projects) {
        $stores = @(Get-ChildItem -Path $projects -Directory -ErrorAction SilentlyContinue |
            ForEach-Object { Join-Path $_.FullName 'memory' } |
            Where-Object {
                $m = Join-Path $_ 'MEMORY.md'
                (Test-Path $m) -and ([System.IO.File]::ReadAllText($m) -like '*Generated by SkyOps*')
            })
    }
    if ($stores.Count -eq 0) {
        Write-Host "  (no SkyOps-managed store found)" -ForegroundColor DarkGray
    }
    foreach ($store in $stores) {
        try {
            & $memTool index -MemoryRoot $store
        } catch {
            Write-Host "  skipped $store ($($_.Exception.Message))" -ForegroundColor DarkGray
        }
    }
} elseif ($DryRun) {
    Write-Host "  would reindex every SkyOps-managed MEMORY.md"
} else {
    Write-Host "  (memory tool not installed)"
}

# 8. Prune orphans.
#    The installer used to only ever copy, so a renamed or retired asset lingered in
#    ~/.claude forever - costing description tokens in every session and still being
#    offered to the model. Anything installed that the repo no longer owns is removed.
Write-Host "Prune:" -ForegroundColor Green
$expectedCmds = @()
Get-ChildItem -Path (Join-Path $RepoRoot 'commands') -Filter '*.md' -File | ForEach-Object { $expectedCmds += $_.Name }
Get-ChildItem -Path (Join-Path $RepoRoot 'skills') -Directory | ForEach-Object {
    if (Test-Path (Join-Path $_.FullName 'SKILL.md')) { $expectedCmds += "$($_.Name).md" }
}
if (Test-Path $packRoot) {
    Get-ChildItem -Path $packRoot -Directory | ForEach-Object {
        $pm = Join-Path $_.FullName 'PACK.md'
        if (Test-Path $pm) {
            $m = [System.IO.File]::ReadAllText($pm)
            $pn = if ($m -match '(?m)^name:\s*(\S+)') { $Matches[1] } else { "sky-rules-$($_.Name)" }
            $expectedCmds += "$pn.md"
        }
    }
}
$expectedAgents = @(Get-ChildItem -Path (Join-Path $RepoRoot 'agents') -Filter '*.md' -File |
    Where-Object { $_.Name -ne 'README.md' -and $_.Name -ne '_OUTPUT-CONTRACT.md' } | ForEach-Object { $_.Name })

$pruned = 0
foreach ($pair in @(@{ Dir = $CmdDst; Keep = $expectedCmds }, @{ Dir = $AgentDst; Keep = $expectedAgents })) {
    if (-not (Test-Path $pair.Dir)) { continue }
    Get-ChildItem -Path $pair.Dir -Filter '*.md' -File | ForEach-Object {
        if ($pair.Keep -notcontains $_.Name) {
            if ($DryRun) { Write-Host "  would remove -> $($_.FullName)" }
            else { Remove-Item $_.FullName -Force; Write-Host "  removed $($_.Name)" -ForegroundColor DarkYellow }
            $pruned++
        }
    }
}
# Stale non-.md artifacts from older installs.
Get-ChildItem -Path $CmdDst -Filter '*.bak' -File -ErrorAction SilentlyContinue | ForEach-Object {
    if (-not $DryRun) { Remove-Item $_.FullName -Force; Write-Host "  removed $($_.Name)" -ForegroundColor DarkYellow }
    $pruned++
}
if ($pruned -eq 0) { Write-Host "  (nothing orphaned)" }

# 9. Consistency lint.
#    File-existence checks miss the failures that actually hurt: a skill referenced by
#    another skill but not invocable by the model (dead lane), a guard script sitting
#    in bin/ that no hook ever calls (unenforced rule), a description long enough to
#    tax every session. Findings go to a warnings file that SessionStart surfaces, so
#    a broken wire is visible instead of silently costing months of degraded runs.
Write-Host "Lint:" -ForegroundColor Green
$problems = @()

# Build a table of every installed asset: name -> model-invocable?
$assets = @{}
Get-ChildItem -Path $CmdDst -Filter '*.md' -File -ErrorAction SilentlyContinue | ForEach-Object {
    $t = [System.IO.File]::ReadAllText($_.FullName)
    $fm = if ($t -match '(?s)^---(.*?)^---') { $Matches[1] } else { '' }
    $assets[$_.BaseName] = @{
        Invocable = ($fm -notmatch '(?m)^disable-model-invocation:\s*true')
        Desc      = if ($fm -match '(?m)^description:\s*(.+)$') { $Matches[1].Trim() } else { '' }
    }
}
$agentNames = @(Get-ChildItem -Path $AgentDst -Filter '*.md' -File -ErrorAction SilentlyContinue | ForEach-Object { $_.BaseName })

# 9a. Cross-reference check: a sky-* name mentioned in a body must resolve, and if it
#     resolves to a skill it must be model-invocable or the caller cannot start it.
Get-ChildItem -Path $CmdDst -Filter '*.md' -File -ErrorAction SilentlyContinue | ForEach-Object {
    $caller = $_.BaseName
    $body = [System.IO.File]::ReadAllText($_.FullName)
    $body = [regex]::Replace($body, '(?s)^---.*?^---', '')
    foreach ($m in [regex]::Matches($body, '`(sky-[a-z0-9-]+)`')) {
        $ref = $m.Groups[1].Value
        if ($ref -eq $caller) { continue }
        if ($agentNames -contains $ref) { continue }
        if (-not $assets.ContainsKey($ref)) {
            $problems += "BROKEN REF  $caller -> '$ref' does not exist as a skill or an agent"
        } elseif (-not $assets[$ref].Invocable) {
            $problems += "DEAD LANE   $caller invokes '$ref', but it has disable-model-invocation: true (model cannot start it)"
        }
    }
}

# 9b. Description budget. Only model-invocable assets are paid for in every session.
foreach ($k in $assets.Keys) {
    if ($assets[$k].Invocable -and $assets[$k].Desc.Length -gt 160) {
        $problems += "LONG DESC   $k description is $($assets[$k].Desc.Length) chars (budget 160) - paid every session"
    }
}

# 9c. Hook wiring. A guard script that no hook calls enforces nothing.
$settings = Join-Path $ClaudeHome 'settings.json'
if (Test-Path $settings) {
    $settingsText = [System.IO.File]::ReadAllText($settings)
    $wiring = @{
        'skyops-intent'  = 'UserPromptSubmit (intent routing)'
        'sky-test-nudge' = 'PostToolUse Edit|Write (test loop nudge)'
        'sky-guard'      = 'PreToolUse Bash (destructive git/SQL guard)'
        'sky-precompact' = 'PreCompact (persist ticket state before context is lost)'
        'install.ps1'    = 'SessionStart (framework sync)'
    }
    foreach ($k in $wiring.Keys) {
        if ($settingsText -notmatch [regex]::Escape($k)) {
            $problems += "UNWIRED     $k is not referenced in settings.json - expected: $($wiring[$k])"
        }
    }
}

if ($problems.Count -eq 0) {
    Write-Host "  clean ($($assets.Count) assets, $($agentNames.Count) agents)"
    if (Test-Path $WarnFile) { Remove-Item $WarnFile -Force }
} else {
    $problems | ForEach-Object { Write-Host "  $_" -ForegroundColor Yellow }
    if (-not $DryRun) {
        $hdr = "SkyOps lint found $($problems.Count) problem(s) - run: pwsh $RepoRoot\install.ps1"
        [System.IO.File]::WriteAllText($WarnFile, (@($hdr) + $problems) -join "`n", [System.Text.UTF8Encoding]::new($false))
    }
}

# 10. Record the stamp last, so a failed run retries next session instead of being
#     skipped by the gate.
if ($stamp -and -not $DryRun) {
    [System.IO.File]::WriteAllText($StampFile, $stamp, [System.Text.UTF8Encoding]::new($false))
}

Write-Host ""
Write-Host "Done. Restart Claude Code (or reload) to pick up changes." -ForegroundColor Cyan
