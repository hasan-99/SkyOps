<#
.SYNOPSIS
  SkyOps memory manager — indexes, classifies, ages, and archives Claude Code memory.

.DESCRIPTION
  Claude Code's native auto-memory is a flat folder of markdown files plus a
  MEMORY.md index that is loaded into every session. Left alone it grows without
  bound: every completed Jira leaves its state behind and startup memory slowly
  fills with history that is no longer true.

  This script is the SkyOps layer on top of that store. It reads only YAML
  frontmatter (never file bodies), so it is cheap enough to run at SessionStart,
  and it is fully deterministic — running it twice produces the same result.

  Storage layout it maintains:

    <memory root>/
      MEMORY.md            generated index, loaded every session
      *.md                 active entries (environment/procedures/decisions/
                           active-ticket/lesson)
      archive/
        ARCHIVE.md         generated index of archived entries
        *.md               completed ticket state — retrievable, not loaded

  Permanent behavioural rules are NOT stored here. They live in the SkyOps repo
  under memory/rules/ and are generated into ~/.claude/CLAUDE.md by install.ps1.

.PARAMETER Command
  index     Regenerate MEMORY.md (and archive/ARCHIVE.md) from frontmatter.
  status    Short summary: counts per category, stale entries, completed tickets
            still sitting in active memory.
  audit     Full health report: uncategorised entries, stale entries, completed
            tickets awaiting archival, credential-shaped content, broken [[links]],
            oversized entries.
  classify  Set category/status/ticket fields on one entry.
  stamp     Set last_verified to today and review_after to the category default.
  archive   Move an entry (or a whole ticket) into archive/ and reindex.
  restore   Move an archived entry back into active memory.
  find      Search active and archived entries by keyword.
  migrate   Bulk-classify from a TSV map (one-time migrations).

.EXAMPLE
  pwsh ./skyops-memory.ps1 index
  pwsh ./skyops-memory.ps1 audit
  pwsh ./skyops-memory.ps1 classify -Name cls-15379-alerts-export -Category active-ticket -TicketState uncommitted
  pwsh ./skyops-memory.ps1 archive -Ticket CLS-15064 -Reason "approved, Nefeli merges"
  pwsh ./skyops-memory.ps1 find -Query "socanalyst"
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet('index', 'status', 'audit', 'classify', 'stamp', 'archive', 'restore', 'find', 'migrate')]
    [string]$Command = 'status',

    [string]$MemoryRoot,
    [string]$Name,
    [string]$Ticket,
    [string]$Category,
    [string]$Status,
    [string]$TicketState,
    # Positional so the documented form works: `skyops-memory.ps1 find <term>`.
    # It was -Query only, which meant the command printed in MEMORY.md and in the
    # memory rule failed outright - and the whole lean-index design depends on that
    # one command working for someone who has never read this file.
    [Parameter(Position = 1)]
    [string]$Query,
    [string]$Map,
    [string]$Reason,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
$InvariantCulture = [System.Globalization.CultureInfo]::InvariantCulture
$Today = [DateTime]::Now.ToString('yyyy-MM-dd', $InvariantCulture)

$ValidCategories = @('rules', 'environment', 'procedures', 'decisions', 'active-ticket', 'lesson', 'archive')
$ValidStatuses = @('active', 'stable', 'stale', 'archived')
$ActiveTicketStates = @('in-progress', 'uncommitted', 'committed', 'review', 'blocked')
$DoneTicketStates = @('done', 'merged', 'approved', 'no-work', 'completed')

# How long an entry of each category stays trustworthy before it should be re-verified.
# Categories absent from this map do not expire and get no review_after stamp.
$ReviewWindowDays = @{
    'active-ticket' = 14
    'environment'   = 180
    'procedures'    = 180
}

# Display order and headings for the generated index.
$CategoryOrder = @(
    @{ Key = 'environment';   Heading = 'Environment and tooling' }
    @{ Key = 'procedures';    Heading = 'Procedures' }
    @{ Key = 'decisions';     Heading = 'Project decisions' }
    @{ Key = 'active-ticket'; Heading = 'Active tickets' }
    @{ Key = 'lesson';        Heading = 'Lessons learned' }
)

# ---------------------------------------------------------------- memory root

function Resolve-MemoryRoot {
    param([string]$Explicit)

    if ($Explicit) { return $Explicit }
    if ($env:SKYOPS_MEMORY_ROOT) { return $env:SKYOPS_MEMORY_ROOT }

    $projects = Join-Path $env:USERPROFILE '.claude\projects'
    if (-not (Test-Path $projects)) {
        throw "No Claude projects folder at $projects. Pass -MemoryRoot explicitly."
    }

    # Claude Code slugifies the project path: C:\Users\hjahouse -> C--Users-hjahouse.
    # Walk up from the cwd so a session sitting in a subfolder still resolves to its
    # own project store rather than falling through to the ambiguous branch.
    $dir = (Get-Location).Path
    while ($dir) {
        $slug = $dir -replace ':', '-' -replace '[\\/]', '-'
        $bySlug = Join-Path $projects "$slug\memory"
        if (Test-Path $bySlug) { return $bySlug }
        $parent = Split-Path -Parent $dir
        if ($parent -eq $dir) { break }
        $dir = $parent
    }

    $candidates = @(Get-ChildItem -Path $projects -Directory -ErrorAction SilentlyContinue |
        ForEach-Object { Join-Path $_.FullName 'memory' } |
        Where-Object { Test-Path $_ })

    if ($candidates.Count -eq 0) { throw "No memory store found under $projects." }
    if ($candidates.Count -eq 1) { return $candidates[0] }

    # Several stores and the cwd matched none. Prefer one SkyOps already manages;
    # never guess between unmanaged stores, because index would rewrite the wrong one.
    $managed = @($candidates | Where-Object {
        $m = Join-Path $_ 'MEMORY.md'
        (Test-Path $m) -and ([System.IO.File]::ReadAllText($m) -like '*Generated by SkyOps*')
    })
    if ($managed.Count -eq 1) { return $managed[0] }

    throw "Cannot tell which memory store to use from '$((Get-Location).Path)'. Pass -MemoryRoot explicitly. Candidates: $($candidates -join '; ')"
}

# ------------------------------------------------------------- frontmatter io

function Read-Frontmatter {
    <#
      Parses the YAML frontmatter block only — never the body. Returns a hashtable
      of top-level keys plus the flattened metadata.* keys, or $null if the file
      has no frontmatter.
    #>
    param([string]$Path)

    $lines = [System.IO.File]::ReadAllLines($Path)
    if ($lines.Count -eq 0 -or $lines[0].Trim() -ne '---') { return $null }

    $fm = @{ _file = $Path; _name = [System.IO.Path]::GetFileNameWithoutExtension($Path) }
    $inMetadata = $false

    for ($i = 1; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        if ($line.Trim() -eq '---') { break }
        if ($line -match '^\s*$' -or $line -match '^\s*#') { continue }

        if ($line -match '^metadata:\s*$') { $inMetadata = $true; continue }
        if ($line -match '^\S' -and $line -notmatch '^metadata:') { $inMetadata = $false }

        if ($line -match '^\s*([A-Za-z_][A-Za-z0-9_]*)\s*:\s*(.*)$') {
            $key = $Matches[1]
            $value = $Matches[2].Trim()
            if ($value.Length -ge 2) {
                if (($value.StartsWith('"') -and $value.EndsWith('"')) -or
                    ($value.StartsWith("'") -and $value.EndsWith("'"))) {
                    $value = $value.Substring(1, $value.Length - 2)
                }
            }
            if ($inMetadata -and $line -match '^\s+') { $fm["meta_$key"] = $value }
            else { $fm[$key] = $value }
        }
    }
    return $fm
}

function Set-MetadataField {
    <#
      Updates or inserts a metadata.<key> in a memory file's frontmatter, leaving
      the body and every other line byte-identical.
    #>
    param(
        [string]$Path,
        [hashtable]$Fields,
        [switch]$WhatIfOnly
    )

    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.AddRange([string[]][System.IO.File]::ReadAllLines($Path))

    if ($lines.Count -eq 0 -or $lines[0].Trim() -ne '---') {
        throw "No frontmatter in $Path — refusing to rewrite."
    }

    $fmEnd = -1
    for ($i = 1; $i -lt $lines.Count; $i++) {
        if ($lines[$i].Trim() -eq '---') { $fmEnd = $i; break }
    }
    if ($fmEnd -lt 0) { throw "Unterminated frontmatter in $Path — refusing to rewrite." }

    $metaIdx = -1
    for ($i = 1; $i -lt $fmEnd; $i++) {
        if ($lines[$i] -match '^metadata:\s*$') { $metaIdx = $i; break }
    }
    if ($metaIdx -lt 0) {
        $lines.Insert($fmEnd, 'metadata:')
        $metaIdx = $fmEnd
        $fmEnd++
    }

    # Last line belonging to the metadata block.
    $metaEnd = $metaIdx
    for ($i = $metaIdx + 1; $i -lt $fmEnd; $i++) {
        if ($lines[$i] -match '^\s+\S') { $metaEnd = $i } else { break }
    }

    foreach ($key in $Fields.Keys) {
        $value = $Fields[$key]
        $replaced = $false
        for ($i = $metaIdx + 1; $i -le $metaEnd; $i++) {
            if ($lines[$i] -match "^\s+$([regex]::Escape($key))\s*:") {
                if ($null -eq $value) { $lines.RemoveAt($i); $metaEnd--; $fmEnd-- }
                else { $lines[$i] = "  ${key}: $value" }
                $replaced = $true
                break
            }
        }
        if (-not $replaced -and $null -ne $value) {
            $lines.Insert($metaEnd + 1, "  ${key}: $value")
            $metaEnd++
            $fmEnd++
        }
    }

    if ($WhatIfOnly) { return }
    [System.IO.File]::WriteAllLines($Path, $lines, [System.Text.UTF8Encoding]::new($false))
}

function Get-Entries {
    param([string]$Root, [switch]$IncludeArchive)

    $files = @(Get-ChildItem -Path $Root -Filter '*.md' -File |
        Where-Object { $_.Name -ne 'MEMORY.md' })

    if ($IncludeArchive) {
        $archiveDir = Join-Path $Root 'archive'
        if (Test-Path $archiveDir) {
            $files += @(Get-ChildItem -Path $archiveDir -Filter '*.md' -File |
                Where-Object { $_.Name -ne 'ARCHIVE.md' })
        }
    }

    $entries = foreach ($f in $files) {
        $fm = Read-Frontmatter $f.FullName
        if ($null -eq $fm) { continue }
        $fm['_size'] = $f.Length
        $fm['_archived'] = $f.DirectoryName.EndsWith('archive')
        [pscustomobject]$fm
    }
    return @($entries)
}

function Get-Category { param($Entry) if ($Entry.meta_category) { $Entry.meta_category } else { '' } }
function Get-Title {
    param($Entry)
    # A human label for the index: the description's leading clause, else the slug.
    #
    # Hard-capped, because this file is loaded into EVERY session. The index exists to
    # tell you an entry is there and roughly what it covers - enough to decide whether
    # to open it. The full description lives in the entry itself, one Read away. Some
    # hooks had grown past 200 characters, which across ~58 entries was most of the
    # file's cost for detail nobody reads at startup.
    $d = $Entry.description
    if (-not $d) { return $Entry._name }
    $cap = 88
    if ($d.Length -le $cap) { return $d }
    # Cut on a word boundary so the hook still reads as a phrase.
    $cut = $d.Substring(0, $cap)
    $sp = $cut.LastIndexOf(' ')
    if ($sp -gt 40) { $cut = $cut.Substring(0, $sp) }
    "$($cut.TrimEnd(' ', ',', ';', '-', '—'))…"
}

function Test-Stale {
    param($Entry)
    if ($Entry.meta_status -eq 'stale') { return $true }
    if (-not $Entry.meta_review_after) { return $false }
    $parsed = [DateTime]::MinValue
    $ok = [DateTime]::TryParseExact(
        $Entry.meta_review_after, 'yyyy-MM-dd', $InvariantCulture,
        [System.Globalization.DateTimeStyles]::None, [ref]$parsed)
    if (-not $ok) { return $false }
    return $parsed.Date -lt [DateTime]::Now.Date
}

# ------------------------------------------------------------------- commands

function Invoke-Index {
    param([string]$Root)

    $entries = Get-Entries -Root $Root
    $archived = @(Get-Entries -Root $Root -IncludeArchive | Where-Object { $_._archived })

    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine("<!-- Generated by SkyOps skyops-memory.ps1 on $Today. Do not edit by hand:")
    [void]$sb.AppendLine("     the next SessionStart sync overwrites this file. Edit the individual")
    [void]$sb.AppendLine("     memory entries, or the SkyOps repo, and re-run the installer. -->")
    [void]$sb.AppendLine()

    # LEAN INDEX (default).
    #
    # This file is loaded into every session and then re-read on every turn for the
    # life of that session. Carrying 58 one-line summaries meant paying for all of
    # them on every ticket, to surface maybe one. Memory should be something you go
    # and get when the work calls for it - not baggage on every prompt.
    #
    # So the default index carries counts and the lookup command, not content. Set
    # SKYOPS_MEMORY_INDEX=full to restore the old listing.
    if ($env:SKYOPS_MEMORY_INDEX -ne 'full') {
        $byCat = @{}
        foreach ($e in $entries) {
            $k = Get-Category $e
            if (-not $k) { $k = 'uncategorised' }
            $byCat[$k] = 1 + $(if ($byCat.ContainsKey($k)) { $byCat[$k] } else { 0 })
        }
        $parts = @()
        foreach ($g in $CategoryOrder) {
            if ($byCat.ContainsKey($g.Key)) { $parts += "$($g.Key) $($byCat[$g.Key])" }
        }
        if ($byCat.ContainsKey('uncategorised')) { $parts += "uncategorised $($byCat['uncategorised'])" }

        [void]$sb.AppendLine('# Memory — lookup, not payload')
        [void]$sb.AppendLine()
        [void]$sb.AppendLine("**$($entries.Count) entries are stored and $($archived.Count) archived. Their contents are deliberately NOT in this file.**")
        [void]$sb.AppendLine('Carrying every summary in every session costs tokens on every turn to surface, at most, one of them.')
        [void]$sb.AppendLine()
        [void]$sb.AppendLine(($parts -join ' · '))
        [void]$sb.AppendLine()
        [void]$sb.AppendLine('## Go and get it when the work calls for it')
        [void]$sb.AppendLine()
        [void]$sb.AppendLine('Search **before** you start ticket work, debug a failure, or touch an unfamiliar area —')
        [void]$sb.AppendLine('the answer may already be here, including in the archive:')
        [void]$sb.AppendLine()
        [void]$sb.AppendLine('```bash')
        [void]$sb.AppendLine('pwsh ~/.claude/bin/skyops-memory.ps1 find <term>    # searches active AND archived')
        [void]$sb.AppendLine('pwsh ~/.claude/bin/skyops-memory.ps1 status         # full active list')
        [void]$sb.AppendLine('```')
        [void]$sb.AppendLine()
        [void]$sb.AppendLine("Entries are one file each in this folder, named by slug — `Read` one directly when you know it.")
        [void]$sb.AppendLine('Behavioural rules are not here: they live in `CLAUDE.md`, which is always loaded.')
        [void]$sb.AppendLine()

        $target = Join-Path $Root 'MEMORY.md'
        $new = $sb.ToString()
        $cur = if (Test-Path $target) { [System.IO.File]::ReadAllText($target) } else { '' }
        if ($DryRun) {
            Write-Host "  would write lean $target"
        } elseif ($cur -ceq $new) {
            Write-Host "  MEMORY.md unchanged (lean: $($entries.Count) entries, $($archived.Count) archived)"
        } else {
            [System.IO.File]::WriteAllText($target, $new, [System.Text.UTF8Encoding]::new($false))
            Write-Host "  MEMORY.md — lean index ($($entries.Count) entries, $($archived.Count) archived)"
        }
        if ($archived.Count -gt 0) { Write-ArchiveIndex -Root $Root -Archived $archived }
        return
    }

    [void]$sb.AppendLine('Behavioural rules are not listed here. They are permanent, live in the SkyOps repo')
    [void]$sb.AppendLine('under `memory/rules/`, and are generated into `CLAUDE.md`, which is always loaded.')
    [void]$sb.AppendLine()

    # Ticket entries are the volatile ones: the volatile-state rule forbids trusting
    # any of them without re-checking, so listing fifteen costs ~2,000 tokens in every
    # session to surface pointers that must be re-verified anyway. Cap the list at the
    # most recently touched few and collapse the tail to one line. Nothing is deleted
    # and nothing moves - the entries are still on disk and still findable.
    $ActiveTicketCap = 5
    $staleDays = 14
    $autoArchivable = 0

    $listed = 0
    foreach ($group in $CategoryOrder) {
        $items = @($entries | Where-Object { (Get-Category $_) -eq $group.Key } | Sort-Object _name)
        if ($items.Count -eq 0) { continue }

        $overflow = @()
        if ($group.Key -eq 'active-ticket' -and $items.Count -gt $ActiveTicketCap) {
            # Recency by file mtime: always present, and it tracks the last real edit
            # better than any hand-maintained frontmatter field.
            $items = @($items | Sort-Object -Property @{
                Expression = {
                    $p = Join-Path $Root "$($_._name).md"
                    if (Test-Path $p) { (Get-Item $p).LastWriteTime } else { [DateTime]::MinValue }
                }
            } -Descending)
            $overflow = @($items[$ActiveTicketCap..($items.Count - 1)])
            $items = @($items[0..($ActiveTicketCap - 1)])
        }

        [void]$sb.AppendLine("## $($group.Heading)")
        [void]$sb.AppendLine()

        # Lessons are recalled by topic, not browsed at startup. A name is enough to
        # know one exists and to open it; the hook text beside it was ~60% of this
        # section's cost for detail that is one Read away. Names stay in full so the
        # slug is still searchable and still tells you what it is about.
        if ($group.Key -eq 'lesson') {
            foreach ($e in ($items | Sort-Object _name)) {
                [void]$sb.AppendLine("- [$($e._name)]($($e._name).md)")
                $listed++
            }
            [void]$sb.AppendLine()
            [void]$sb.AppendLine('_Open any entry for the full lesson, or `/sky-memory find <term>`._')
            [void]$sb.AppendLine()
            continue
        }

        foreach ($e in $items) {
            $marks = @()
            if ($e.meta_ticket_state) { $marks += $e.meta_ticket_state }
            if (Test-Stale $e) { $marks += 'stale — re-verify' }
            $suffix = if ($marks.Count) { " _($($marks -join ', '))_" } else { '' }
            [void]$sb.AppendLine("- [$($e._name)]($($e._name).md) — $(Get-Title $e)$suffix")
            $listed++
        }
        if ($overflow.Count -gt 0) {
            $names = @($overflow | ForEach-Object { $_._name } | Sort-Object)
            $preview = if ($names.Count -gt 6) { ($names[0..5] -join ', ') + ', ...' } else { $names -join ', ' }
            [void]$sb.AppendLine("- _**$($overflow.Count) older ticket entries** not listed: $($preview)_")
            [void]$sb.AppendLine('  Run `/sky-memory status` for the full list, or open the file by name.')
            foreach ($e in $overflow) {
                $p = Join-Path $Root "$($e._name).md"
                if ((Test-Path $p) -and ((Get-Item $p).LastWriteTime -lt [DateTime]::Now.AddDays(-$staleDays))) {
                    $autoArchivable++
                }
            }
        }
        [void]$sb.AppendLine()
    }

    $uncategorised = @($entries | Where-Object { -not (Get-Category $_) } | Sort-Object _name)
    if ($uncategorised.Count -gt 0) {
        [void]$sb.AppendLine('## Uncategorised')
        [void]$sb.AppendLine()
        [void]$sb.AppendLine('_Run `skyops-memory.ps1 classify` to file these._')
        [void]$sb.AppendLine()
        foreach ($e in $uncategorised) {
            [void]$sb.AppendLine("- [$($e._name)]($($e._name).md) — $(Get-Title $e)")
            $listed++
        }
        [void]$sb.AppendLine()
    }

    # The whole point: history collapses to a single line instead of N lines.
    [void]$sb.AppendLine('## Archive')
    [void]$sb.AppendLine()
    if ($archived.Count -eq 0) {
        [void]$sb.AppendLine('- _(empty)_')
    }
    else {
        $keys = @($archived | ForEach-Object { if ($_.meta_ticket) { $_.meta_ticket } else { $_._name } } | Sort-Object -Unique)
        $preview = if ($keys.Count -gt 8) { ($keys[0..7] -join ', ') + ', ...' } else { $keys -join ', ' }
        [void]$sb.AppendLine("- **$($archived.Count) completed entries**, not loaded at startup: $preview")
        [void]$sb.AppendLine('- Retrieve with `/sky-memory find <term>` or see `archive/ARCHIVE.md`. Nothing is deleted.')
    }
    [void]$sb.AppendLine()

    $target = Join-Path $Root 'MEMORY.md'
    if ($DryRun) {
        Write-Host "  would write $target ($listed active, $($archived.Count) archived)"
    }
    else {
        # First time SkyOps touches a store, the existing MEMORY.md is hand-written
        # and has no backup anywhere. Preserve it before taking the file over.
        if (Test-Path $target) {
            $existing = [System.IO.File]::ReadAllText($target)
            if ($existing -notlike '*Generated by SkyOps*') {
                $backupDir = Join-Path $Root '.memory-backup'
                if (-not (Test-Path $backupDir)) { New-Item -ItemType Directory -Force -Path $backupDir | Out-Null }
                $stamp = [DateTime]::Now.ToString('yyyyMMdd-HHmmss', $InvariantCulture)
                Copy-Item $target (Join-Path $backupDir "MEMORY.md.$stamp.pre-skyops.bak") -Force
                Write-Host "  backed up the hand-written MEMORY.md -> .memory-backup\MEMORY.md.$stamp.pre-skyops.bak"
            }
        }
        # Compare before writing. MEMORY.md sits in the cached prompt prefix, and
        # prompt caching is a PREFIX match - any byte change invalidates everything
        # after it, so a needless rewrite makes the session re-pay full input price
        # for the whole context behind it. Rewriting identical bytes is harmless to
        # the cache but still churns the file watcher, which re-injects the diff into
        # the running session as a "changed on disk" notice. Both are avoidable.
        $new = $sb.ToString()
        $cur = if (Test-Path $target) { [System.IO.File]::ReadAllText($target) } else { '' }
        if ($cur -ceq $new) {
            Write-Host "  MEMORY.md unchanged ($listed active, $($archived.Count) archived)"
        } else {
            [System.IO.File]::WriteAllText($target, $new, [System.Text.UTF8Encoding]::new($false))
            Write-Host "  MEMORY.md — $listed active entries, $($archived.Count) archived"
        }
        # Deliberately a hint, not an action. `index` runs on every SessionStart, and
        # silently moving a ticket entry out from under an in-progress task would be a
        # surprise that is hard to trace. Archiving stays an explicit decision.
        if ($autoArchivable -gt 0) {
            Write-Host "  $autoArchivable ticket entr$(if ($autoArchivable -eq 1) { 'y' } else { 'ies' }) untouched for 14+ days — consider: skyops-memory.ps1 archive <name>" -ForegroundColor DarkGray
        }
    }

    if ($archived.Count -gt 0) { Write-ArchiveIndex -Root $Root -Archived $archived }
}

function Write-ArchiveIndex {
    param([string]$Root, $Archived)

    $dir = Join-Path $Root 'archive'
    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine("<!-- Generated by SkyOps skyops-memory.ps1 on $Today. -->")
    [void]$sb.AppendLine()
    [void]$sb.AppendLine('# Archived memory')
    [void]$sb.AppendLine()
    [void]$sb.AppendLine('Completed ticket state. Kept in full, deliberately outside the startup index.')
    [void]$sb.AppendLine('Reusable knowledge from these was extracted into `lesson` entries before archival.')
    [void]$sb.AppendLine()
    [void]$sb.AppendLine('| Ticket | Entry | Final state | Archived | Summary |')
    [void]$sb.AppendLine('|---|---|---|---|---|')

    foreach ($e in ($Archived | Sort-Object { $_.meta_ticket }, _name)) {
        $key = if ($e.meta_ticket) { $e.meta_ticket } else { '—' }
        $state = if ($e.meta_ticket_state) { $e.meta_ticket_state } else { '—' }
        $when = if ($e.meta_archived_on) { $e.meta_archived_on } else { '—' }
        $desc = (Get-Title $e) -replace '\|', '\|'
        [void]$sb.AppendLine("| $key | [$($e._name)]($($e._name).md) | $state | $when | $desc |")
    }

    if ($DryRun) { Write-Host "  would write $dir\ARCHIVE.md"; return }
    [System.IO.File]::WriteAllText((Join-Path $dir 'ARCHIVE.md'), $sb.ToString(), [System.Text.UTF8Encoding]::new($false))
    Write-Host "  archive/ARCHIVE.md — $($Archived.Count) entries"
}

function Invoke-Status {
    param([string]$Root)

    $entries = Get-Entries -Root $Root
    $archived = @(Get-Entries -Root $Root -IncludeArchive | Where-Object { $_._archived })

    Write-Host "SkyOps memory — $Root" -ForegroundColor Cyan
    Write-Host ''
    foreach ($group in $CategoryOrder) {
        $n = @($entries | Where-Object { (Get-Category $_) -eq $group.Key }).Count
        if ($n) { Write-Host ("  {0,-22} {1}" -f $group.Key, $n) }
    }
    $unc = @($entries | Where-Object { -not (Get-Category $_) }).Count
    if ($unc) { Write-Host ("  {0,-22} {1}" -f 'uncategorised', $unc) -ForegroundColor Yellow }
    Write-Host ("  {0,-22} {1}" -f 'archived', $archived.Count) -ForegroundColor DarkGray
    Write-Host ''

    $stale = @($entries | Where-Object { Test-Stale $_ })
    if ($stale.Count) {
        Write-Host "  Stale — re-verify before quoting:" -ForegroundColor Yellow
        $stale | ForEach-Object { Write-Host "    $($_._name)" }
        Write-Host ''
    }

    $done = @($entries | Where-Object { $_.meta_ticket_state -and $DoneTicketStates -contains $_.meta_ticket_state })
    if ($done.Count) {
        Write-Host "  Completed tickets still in active memory — archive them:" -ForegroundColor Yellow
        $done | ForEach-Object { Write-Host "    $($_._name)  ($($_.meta_ticket_state))" }
    }
}

function Invoke-Audit {
    param([string]$Root)

    $entries = Get-Entries -Root $Root -IncludeArchive
    $active = @($entries | Where-Object { -not $_._archived })
    $issues = 0

    Write-Host "SkyOps memory audit — $Root" -ForegroundColor Cyan
    Write-Host ''

    function Report($title, $items, $colour) {
        if ($items.Count -eq 0) { return 0 }
        Write-Host "  $title" -ForegroundColor $colour
        $items | ForEach-Object { Write-Host "    $_" }
        Write-Host ''
        return $items.Count
    }

    $issues += Report 'Uncategorised (not filed into a memory category)' `
        @($active | Where-Object { -not (Get-Category $_) } | ForEach-Object { $_._name }) 'Yellow'

    $issues += Report 'Invalid category' `
        @($active | Where-Object { (Get-Category $_) -and $ValidCategories -notcontains (Get-Category $_) } |
            ForEach-Object { "$($_._name) -> $($_.meta_category)" }) 'Red'

    $issues += Report 'Invalid status' `
        @($active | Where-Object { $_.meta_status -and $ValidStatuses -notcontains $_.meta_status } |
            ForEach-Object { "$($_._name) -> $($_.meta_status)" }) 'Red'

    $issues += Report 'Past review_after — re-verify or re-stamp' `
        @($active | Where-Object { Test-Stale $_ } | ForEach-Object { "$($_._name)  (review_after $($_.meta_review_after))" }) 'Yellow'

    $issues += Report 'Volatile but never stamped (no last_verified)' `
        @($active | Where-Object {
            $c = Get-Category $_
            ($ReviewWindowDays.ContainsKey($c)) -and -not $_.meta_last_verified
        } | ForEach-Object { "$($_._name)  ($(Get-Category $_))" }) 'Yellow'

    $issues += Report 'Completed tickets awaiting archival' `
        @($active | Where-Object { $_.meta_ticket_state -and $DoneTicketStates -contains $_.meta_ticket_state } |
            ForEach-Object { "$($_._name)  ($($_.meta_ticket_state))" }) 'Yellow'

    # Credential-shaped content. Reports the location only — never the value.
    $secretPatterns = @('-P\s+', 'password\s*[:=]', 'pwd\s*[:=]', 'api[_-]?key\s*[:=]', 'secret\s*[:=]', 'token\s*[:=]\s*\S')
    $withSecrets = foreach ($e in $entries) {
        $text = [System.IO.File]::ReadAllText($e._file)
        foreach ($p in $secretPatterns) {
            if ($text -match $p) { "$($e._name)  (matched /$p/ — value NOT shown)"; break }
        }
    }
    $issues += Report 'Possible credential in memory — move to ~/.claude/skyops-secrets.local.md' @($withSecrets) 'Red'

    # Broken [[wiki links]].
    $names = @{}
    $entries | ForEach-Object { $names[$_._name] = $true }
    $broken = foreach ($e in $entries) {
        $text = [System.IO.File]::ReadAllText($e._file)
        foreach ($m in [regex]::Matches($text, '\[\[([a-z0-9\-_]+)\]\]')) {
            $t = $m.Groups[1].Value
            if (-not $names.ContainsKey($t)) { "$($e._name) -> [[$t]]" }
        }
    }
    $issues += Report 'Links pointing at a non-existent entry' @($broken | Sort-Object -Unique) 'DarkYellow'

    $issues += Report 'Oversized entries (>8 KB — split or archive)' `
        @($active | Where-Object { $_._size -gt 8192 } |
            ForEach-Object { "$($_._name)  ($([math]::Round($_._size / 1KB)) KB)" }) 'DarkYellow'

    if ($issues -eq 0) { Write-Host '  Clean — nothing to fix.' -ForegroundColor Green }
    else { Write-Host "  $issues item(s) need attention." -ForegroundColor Yellow }
}

function Resolve-EntryPath {
    param([string]$Root, [string]$EntryName)
    $p = Join-Path $Root "$EntryName.md"
    if (Test-Path $p) { return $p }
    $a = Join-Path $Root "archive\$EntryName.md"
    if (Test-Path $a) { return $a }
    throw "No memory entry named '$EntryName' in $Root."
}

function Invoke-Classify {
    param([string]$Root)

    if (-not $Name) { throw 'classify needs -Name.' }
    if ($Category -and $ValidCategories -notcontains $Category) {
        throw "Invalid -Category '$Category'. One of: $($ValidCategories -join ', ')"
    }
    if ($Status -and $ValidStatuses -notcontains $Status) {
        throw "Invalid -Status '$Status'. One of: $($ValidStatuses -join ', ')"
    }

    $path = Resolve-EntryPath -Root $Root -EntryName $Name
    $fields = @{}
    if ($Category) { $fields['category'] = $Category }
    if ($Status) { $fields['status'] = $Status }
    if ($Ticket) { $fields['ticket'] = $Ticket }
    if ($TicketState) { $fields['ticket_state'] = $TicketState }

    # Volatile categories get a verification stamp; durable ones deliberately don't.
    $effective = if ($Category) { $Category } else { (Read-Frontmatter $path).meta_category }
    if ($ReviewWindowDays.ContainsKey($effective)) {
        $fields['last_verified'] = $Today
        $fields['review_after'] = [DateTime]::Now.AddDays($ReviewWindowDays[$effective]).ToString('yyyy-MM-dd', $InvariantCulture)
    }

    if ($fields.Count -eq 0) { throw 'classify needs at least one of -Category/-Status/-Ticket/-TicketState.' }
    Set-MetadataField -Path $path -Fields $fields -WhatIfOnly:$DryRun
    Write-Host "  $Name -> $(($fields.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join ', ')"
}

function Invoke-Stamp {
    param([string]$Root)
    if (-not $Name) { throw 'stamp needs -Name.' }
    $path = Resolve-EntryPath -Root $Root -EntryName $Name
    $fm = Read-Frontmatter $path
    $cat = $fm.meta_category
    $fields = @{ 'last_verified' = $Today }
    if ($ReviewWindowDays.ContainsKey($cat)) {
        $fields['review_after'] = [DateTime]::Now.AddDays($ReviewWindowDays[$cat]).ToString('yyyy-MM-dd', $InvariantCulture)
    }
    if ($fm.meta_status -eq 'stale') { $fields['status'] = 'active' }
    Set-MetadataField -Path $path -Fields $fields -WhatIfOnly:$DryRun
    Write-Host "  $Name — verified $Today"
}

function Invoke-Archive {
    param([string]$Root)

    $targets = @()
    if ($Name) { $targets += $Name }
    elseif ($Ticket) {
        $key = $Ticket.ToLowerInvariant()
        $targets += @(Get-Entries -Root $Root |
            Where-Object { $_._name -like "$key*" -or ($_.meta_ticket -and $_.meta_ticket.ToLowerInvariant() -eq $key) } |
            ForEach-Object { $_._name })
        if ($targets.Count -eq 0) { throw "No active memory entry for ticket '$Ticket'." }
    }
    else { throw 'archive needs -Name or -Ticket.' }

    $dir = Join-Path $Root 'archive'
    if (-not (Test-Path $dir) -and -not $DryRun) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }

    foreach ($t in $targets) {
        $src = Join-Path $Root "$t.md"
        if (-not (Test-Path $src)) { Write-Host "  (already archived: $t)"; continue }

        $fields = @{
            'status'      = 'archived'
            'archived_on' = $Today
        }
        if ($Reason) { $fields['archived_reason'] = $Reason }
        Set-MetadataField -Path $src -Fields $fields -WhatIfOnly:$DryRun

        if ($DryRun) { Write-Host "  would archive $t"; continue }
        # Move, never delete — history stays retrievable.
        Move-Item -Path $src -Destination (Join-Path $dir "$t.md") -Force
        Write-Host "  archived $t"
    }

    Invoke-Index -Root $Root
}

function Invoke-Restore {
    param([string]$Root)
    if (-not $Name) { throw 'restore needs -Name.' }
    $src = Join-Path $Root "archive\$Name.md"
    if (-not (Test-Path $src)) { throw "No archived entry named '$Name'." }
    $dst = Join-Path $Root "$Name.md"
    if ($DryRun) { Write-Host "  would restore $Name"; return }
    Move-Item -Path $src -Destination $dst -Force
    Set-MetadataField -Path $dst -Fields @{ 'status' = 'active'; 'archived_on' = $null; 'archived_reason' = $null }
    Write-Host "  restored $Name"
    Invoke-Index -Root $Root
}

function Invoke-Find {
    param([string]$Root)
    if (-not $Query) { throw 'find needs -Query.' }

    # Search EVERY managed store, not just the one the cwd resolves to.
    #
    # Root resolution is cwd-dependent, so running this from a repo under
    # C:\SharedProjects searched a different (nearly empty) store than running it from
    # the home directory - and returned "no match" for entries that plainly exist.
    # That is fatal for a lookup command: memory is now fetched on demand rather than
    # carried, so a false "no match" means the fact is silently re-derived.
    # An explicit -MemoryRoot still pins the search to one store.
    $roots = @($Root)
    if (-not $MemoryRoot) {
        $projects = Join-Path $env:USERPROFILE '.claude\projects'
        if (Test-Path $projects) {
            $roots = @(Get-ChildItem -Path $projects -Directory -ErrorAction SilentlyContinue |
                ForEach-Object { Join-Path $_.FullName 'memory' } |
                Where-Object { Test-Path $_ })
            if ($roots.Count -eq 0) { $roots = @($Root) }
        }
    }

    $entries = @()
    foreach ($r in $roots) {
        try { $entries += @(Get-Entries -Root $r -IncludeArchive) } catch { }
    }
    $hits = 0
    foreach ($e in ($entries | Sort-Object _archived, _name)) {
        $text = [System.IO.File]::ReadAllText($e._file)
        if ($text -notmatch [regex]::Escape($Query)) { continue }
        $hits++
        $where = if ($e._archived) { 'archive' } else { 'active' }
        Write-Host ("  [{0}] {1}" -f $where, $e._name) -ForegroundColor Cyan
        Write-Host ("         {0}" -f (Get-Title $e))
        $n = 0
        foreach ($line in ($text -split "`r?`n")) {
            if ($line -match [regex]::Escape($Query)) {
                Write-Host ("         | {0}" -f $line.Trim())
                if (++$n -ge 3) { break }
            }
        }
    }
    if ($hits -eq 0) { Write-Host "  No memory entry matches '$Query'." }
    else { Write-Host ''; Write-Host "  $hits match(es). Open the file for the full entry." }
}

function Invoke-Migrate {
    param([string]$Root)
    if (-not $Map) { throw 'migrate needs -Map <path to tsv>.' }
    if (-not (Test-Path $Map)) { throw "Map file not found: $Map" }

    # Columns, whitespace-separated: name category status ticket ticket_state
    # None of the values may contain a space, so any run of whitespace is a
    # separator — the map stays readable as an aligned table.
    # '-' means "leave unset". Lines starting with # are comments.
    $applied = 0; $missing = @()
    foreach ($line in [System.IO.File]::ReadAllLines($Map)) {
        if ($line -match '^\s*#' -or $line -match '^\s*$') { continue }
        $c = $line.Trim() -split '\s+'
        if ($c.Count -lt 2) { continue }

        $entryName = $c[0].Trim()
        $path = Join-Path $Root "$entryName.md"
        if (-not (Test-Path $path)) { $missing += $entryName; continue }

        $fields = @{}
        if ($c[1].Trim() -ne '-') { $fields['category'] = $c[1].Trim() }
        if ($c.Count -gt 2 -and $c[2].Trim() -ne '-') { $fields['status'] = $c[2].Trim() }
        if ($c.Count -gt 3 -and $c[3].Trim() -ne '-') { $fields['ticket'] = $c[3].Trim() }
        if ($c.Count -gt 4 -and $c[4].Trim() -ne '-') { $fields['ticket_state'] = $c[4].Trim() }

        $cat = $fields['category']
        if ($cat -and $ReviewWindowDays.ContainsKey($cat)) {
            $fields['last_verified'] = $Today
            $fields['review_after'] = [DateTime]::Now.AddDays($ReviewWindowDays[$cat]).ToString('yyyy-MM-dd', $InvariantCulture)
        }

        Set-MetadataField -Path $path -Fields $fields -WhatIfOnly:$DryRun
        $applied++
    }

    Write-Host "  classified $applied entr$(if ($applied -eq 1) { 'y' } else { 'ies' })"
    if ($missing.Count) {
        Write-Host "  not found (already archived, or renamed):" -ForegroundColor DarkGray
        $missing | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkGray }
    }
}

# ----------------------------------------------------------------------- main

# `find` searches every store, so it must never die on root resolution. Resolution
# walks up from the cwd, and in the bash Claude Code spawns $HOME is a mapped drive
# (P:\) that matches no project slug - so a plain `find` threw "cannot tell which
# memory store to use" instead of searching. Memory is fetched on demand now, so a
# hard failure here means the fact is silently re-derived. Every other command still
# needs one unambiguous root, and still fails loudly without it.
if ($Command -eq 'find') {
    $root = $null
    try { $root = Resolve-MemoryRoot -Explicit $MemoryRoot } catch { }
} else {
    $root = Resolve-MemoryRoot -Explicit $MemoryRoot
}
if (-not (Test-Path $root)) { throw "Memory root does not exist: $root" }

switch ($Command) {
    'index'    { Invoke-Index    -Root $root }
    'status'   { Invoke-Status   -Root $root }
    'audit'    { Invoke-Audit    -Root $root }
    'classify' { Invoke-Classify -Root $root }
    'stamp'    { Invoke-Stamp    -Root $root }
    'archive'  { Invoke-Archive  -Root $root }
    'restore'  { Invoke-Restore  -Root $root }
    'find'     { Invoke-Find     -Root $root }
    'migrate'  { Invoke-Migrate  -Root $root }
}
