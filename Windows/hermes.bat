@echo off
setlocal
where pwsh >nul 2>&1
if %errorlevel% neq 0 (
    set PS_CMD=powershell
) else (
    set PS_CMD=pwsh
)

%PS_CMD% -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "try { $lines = Get-Content '%~f0'; $marker = $lines.IndexOf('::PS_START'); $ps = $lines[($marker + 1)..($lines.Count - 1)] -join \"`r`n\"; Invoke-Expression $ps } catch { Write-Host ''; Write-Host 'An unexpected error occurred.'; Write-Host $_.Exception.Message; pause; exit 1 }"
pause
goto :eof
::PS_START
$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# Friendly error handler
# ---------------------------------------------------------------------------
function Show-FriendlyError {
    param([string]$Message)
    Write-Host ''
    Write-Host $Message
    pause
    exit 1
}

# ---------------------------------------------------------------------------
# Execution policy guidance
# ---------------------------------------------------------------------------
$execPolicy = Get-ExecutionPolicy -Scope CurrentUser
if ($execPolicy -eq 'Restricted' -or $execPolicy -eq 'Undefined') {
    Write-Host ''
    Write-Host "NOTE: PowerShell execution policy is currently '$execPolicy'."
    Write-Host "To allow scripts to run permanently, use one of these methods:"
    Write-Host ''
    Write-Host '  Recommended (less permissive):'
    Write-Host '    Set-ExecutionPolicy -Scope CurrentUser RemoteSigned'
    Write-Host ''
    Write-Host '  Or use the included launcher:'
    Write-Host '    hermes.bat'
    Write-Host ''
    $cont = Read-Host 'Continue with current session only? (y/N)'
    if ($cont -ne 'y') { exit 0 }
}

# ---------------------------------------------------------------------------
# One-time dependency installer with OS-aware package manager detection
# ---------------------------------------------------------------------------
$DepFlag = Join-Path $env:USERPROFILE ".hermes\.deps_installed"

function Ensure-Dependencies {
    if (Test-Path $DepFlag) { return }

    Write-Host "Checking dependencies..."

    $missing = @()
    -not (Get-Command python3 -ErrorAction SilentlyContinue) -and
    -not (Get-Command python -ErrorAction SilentlyContinue) | Out-Null
    if ($LASTEXITCODE -ne 0) { $missing += "python3" }

    if ($missing.Count -eq 0) {
        New-Item -ItemType File -Path $DepFlag -Force | Out-Null
        return
    }

    Write-Host "Missing: $($missing -join ' ')"
    Write-Host "Detecting package manager..."

    $pkgManager = $null
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        $pkgManager = "winget"
    } elseif (Get-Command choco -ErrorAction SilentlyContinue) {
        $pkgManager = "choco"
    } elseif (Get-Command scoop -ErrorAction SilentlyContinue) {
        $pkgManager = "scoop"
    }

    if (-not $pkgManager) {
        Show-FriendlyError "Python is required, but no supported package manager was found.`nPlease install Python manually from https://www.python.org/downloads/windows/"
    }

    Write-Host "Using package manager: $pkgManager"

    foreach ($pkg in $missing) {
        switch ($pkgManager) {
            "winget" {
                winget install --id Python.Python.3 --accept-package-agreements --accept-source-agreements | Out-Null
            }
            "choco" {
                choco install python -y | Out-Null
            }
            "scoop" {
                scoop install python | Out-Null
            }
        }
    }

    New-Item -ItemType File -Path $DepFlag -Force | Out-Null
    Write-Host "Dependencies installed."
}

Ensure-Dependencies

# ---------------------------------------------------------------------------
# Locate Hermes's state.db
# ---------------------------------------------------------------------------
function Find-HermesDb {
    $candidates = @()

    if ($env:HERMES_REAL_HOME) {
        $candidates += Join-Path $env:HERMES_REAL_HOME ".hermes\state.db"
    }

    $candidates += Join-Path $env:USERPROFILE ".hermes\state.db"
    $candidates += "C:\hermes\state.db"
    $candidates += "C:\Program Files\hermes\state.db"
    $candidates += "C:\Program Files (x86)\hermes\state.db"

    $hermesBin = Get-Command hermes -ErrorAction SilentlyContinue
    if ($hermesBin) {
        $prefix = Split-Path (Split-Path $hermesBin.Source)
        $candidates += Join-Path $prefix "share\hermes\state.db"
        $candidates += Join-Path $prefix ".hermes\state.db"
    }

    foreach ($db in $candidates) {
        if (Test-Path $db) {
            return $db
        }
    }

    return $null
}

$DB = Find-HermesDb
if (-not $DB -or -not (Test-Path $DB)) {
    Show-FriendlyError "Hermes Database Not Found - Is Hermes installed?"
}

Write-Host "Using Hermes DB: $DB"

# ---------------------------------------------------------------------------
# Query sessions
# ---------------------------------------------------------------------------
function Get-Sessions {
    $python = Get-Command python3 -ErrorAction SilentlyContinue
    if (-not $python) { $python = Get-Command python -ErrorAction SilentlyContinue }
    if (-not $python) { Show-FriendlyError "Python is required but was not found. Please install Python 3."; return @() }

    $script = @"
import sqlite3, os
db = os.environ.get('HERMES_DB', '')
if not db:
    import sys
    print('NO_DB', file=sys.stderr)
    sys.exit(1)
conn = sqlite3.connect(db)
cur = conn.cursor()
cur.execute('''
    SELECT id, title, datetime(started_at, 'unixepoch') as started
    FROM sessions
    WHERE profile_name = 'default'
      AND archived = 0
    ORDER BY started_at ASC
''')
for sid, title, started in cur.fetchall():
    title = (title or '(untitled)').replace('|', '/')
    print(f'{title}|{sid}|{started}')
"@

    $env:HERMES_DB = $DB
    $lines = & $python.Source -c $script 2>&1
    if ($lines -match "NO_DB") { return @() }

    $result = @()
    foreach ($line in $lines) {
        if ($line -match '^\s*$') { continue }
        $parts = $line -split '\|'
        if ($parts.Count -ge 3) {
            $result += [PSCustomObject]@{
                Title   = $parts[0]
                Id      = $parts[1]
                Started = $parts[2]
            }
        }
    }
    return $result
}

# ---------------------------------------------------------------------------
# Delete chat menu
# ---------------------------------------------------------------------------
function Show-DeleteMenu {
    Clear-Host
    $sessions = Get-Sessions

    $chatTitles = @()
    $chatIds = @()
    foreach ($s in $sessions) {
        $chatTitles += "$($s.Title) [$($s.Started)]"
        $chatIds += $s.Id
    }

    $chatTitles += "Back"
    $chatIds += "__BACK__"

    while ($true) {
        Write-Host "`nChats:"
        for ($i = 0; $i -lt $chatTitles.Count; $i++) {
            Write-Host ("  {0}) {1}" -f ($i + 1), $chatTitles[$i])
        }

        $selections = Read-Host "`nSelect chats to delete (e.g. 1 2 3, 3-7, or 'b' to go back)"
        if ($selections -eq 'b') { return }

        $expanded = @()
        foreach ($token in $selections -split '\s+') {
            if ($token -match '^(\d+)-(\d+)$') {
                $start = [long]$Matches[1]
                $end   = [long]$Matches[2]
                if ($start -le $end) {
                    for ($n = $start; $n -le $end; $n++) { $expanded += $n }
                } else {
                    for ($n = $start; $n -ge $end; $n--) { $expanded += $n }
                }
            } elseif ($token -match '^\d+$') {
                $expanded += [long]$token
            }
        }

        $toDelete = @()
        foreach ($idx in $expanded) {
            if ($idx -ge 1 -and $idx -le $chatIds.Count) {
                $sid = $chatIds[$idx - 1]
                if ($sid -ne '__BACK__') { $toDelete += $sid }
            }
        }

        if ($toDelete.Count -eq 0) {
            Write-Host "No valid chats selected."
            continue
        }

        Write-Host ("`nSelected {0} chat(s) for deletion." -f $toDelete.Count)
        $confirm = Read-Host "Delete these? This cannot be undone. (y/N)"
        if ($confirm -ne 'y') { continue }

        foreach ($sid in $toDelete) {
            hermes sessions delete $sid --yes 2>$null | Out-Null
        }

        Write-Host "Deleted $($toDelete.Count) chat(s)."
        Start-Sleep -Seconds 2
        return
    }
}

# ---------------------------------------------------------------------------
# Main menu
# ---------------------------------------------------------------------------
function Show-MainMenu {
    Clear-Host
    $sessions = Get-Sessions

    $titles = @()
    $ids    = @()
    foreach ($s in $sessions) {
        $titles += "$($s.Title) [$($s.Started)]"
        $ids    += $s.Id
    }

    $titles += "New Chat"
    $ids    += "__NEW__"

    $titles += "Delete Chat"
    $ids    += "__DEL__"

    $titles += "Exit"
    $ids    += "__EXIT__"

    while ($true) {
        Clear-Host
        Write-Host "Main Menu:`n"
        for ($i = 0; $i -lt $titles.Count; $i++) {
            Write-Host ("  {0}) {1}" -f ($i + 1), $titles[$i])
        }

        $reply = Read-Host "`nEnter number (or 'b' to go back)"
        if ($reply -eq 'b') { continue }

        if ($reply -notmatch '^\d+$') {
            Write-Host "Please enter a valid number."
            Start-Sleep -Seconds 1
            continue
        }

        $idx = [long]$reply - 1
        if ($idx -lt 0 -or $idx -ge $ids.Count) {
            Write-Host "Number out of range."
            Start-Sleep -Seconds 1
            continue
        }

        $sid = $ids[$idx]

        if ($sid -eq "__NEW__") {
            $chatName = Read-Host "Enter a name for the new chat"
            if ([string]::IsNullOrWhiteSpace($chatName)) { $chatName = "New Chat" }
            exec hermes chat --continue $chatName --create-if-missing
        } elseif ($sid -eq "__DEL__") {
            Show-DeleteMenu
        } elseif ($sid -eq "__EXIT__") {
            exit 0
        } else {
            exec hermes chat --resume $sid
        }
    }
}

try {
    Show-MainMenu
} catch {
    Show-FriendlyError "An unexpected error occurred.`n$($_.Exception.Message)"
}
