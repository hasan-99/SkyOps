param(
    [string]$ProjectsRoot = "C:\SharedProjects",
    [string]$CentralGithubPath = "C:\SharedProjects\CopilotOps\.github",
    [switch]$AllProjects
)

if (-not (Test-Path $CentralGithubPath)) {
    Write-Error "Central .github path does not exist: $CentralGithubPath"
    exit 1
}

function Test-IsLink($Path) {
    if (-not (Test-Path $Path)) {
        return $false
    }

    $item = Get-Item $Path -Force
    return ($item.LinkType -eq "Junction" -or $item.LinkType -eq "SymbolicLink" -or $item.LinkType -eq "HardLink")
}

function Backup-IfExists($Path) {
    if (-not (Test-Path $Path)) {
        return $true
    }

    if (Test-IsLink $Path) {
        Write-Host "  Already linked: $Path"
        return $false
    }

    $backupPath = "$Path.backup"

    if (Test-Path $backupPath) {
        Write-Warning "  Conflict exists and backup already exists: $backupPath. Skipping $Path"
        return $false
    }

    Rename-Item $Path $backupPath
    Write-Host "  Backed up: $Path -> $backupPath"
    return $true
}

function Link-Item($ProjectGithubPath, $Name) {
    $target = Join-Path $CentralGithubPath $Name
    $link = Join-Path $ProjectGithubPath $Name

    if (-not (Test-Path $target)) {
        Write-Warning "  Missing central target: $target"
        return
    }

    if (-not (Backup-IfExists $link)) {
        return
    }

    if ((Get-Item $target).PSIsContainer) {
        cmd /c mklink /J "$link" "$target"
    }
    else {
        cmd /c mklink /H "$link" "$target"
    }

    Write-Host "  Linked: $link -> $target"
}

function Link-Project($ProjectPath) {
    Write-Host ""
    Write-Host "Processing: $ProjectPath"

    $projectGithubPath = Join-Path $ProjectPath ".github"

    if (-not (Test-Path $projectGithubPath)) {
        New-Item -ItemType Directory -Path $projectGithubPath | Out-Null
        Write-Host "  Created project .github folder"
    }

    # Link only Copilot-specific assets.
    # Do not replace the entire .github folder because projects may have workflows.
    Link-Item $projectGithubPath "copilot-instructions.md"
    Link-Item $projectGithubPath "instructions"
    Link-Item $projectGithubPath "prompts"
    Link-Item $projectGithubPath "skills"
}

if ($AllProjects) {
    Get-ChildItem $ProjectsRoot -Directory | Where-Object {
        $_.Name -ne "CopilotOps"
    } | ForEach-Object {
        Link-Project $_.FullName
    }
}
else {
    $testProject = Join-Path $ProjectsRoot "CS_Datafactory_v2"
    Link-Project $testProject
}
