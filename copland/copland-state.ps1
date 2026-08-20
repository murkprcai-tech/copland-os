# COPLAND OS -- State-Generator
# schreibt 00_System\STATE.md: maschinenzustand der master-umgebung in EINEM read.
# quelle der wahrheit: die projekt-CLAUDE.mds (kopfzeile: alias/status/Verbunden/Frist).
# trigger: launcher-boot, git post-commit, /merken. staleness-guard: laeuft nur,
# wenn STATE.md aelter 6h ODER eine CLAUDE.md/offene-punkte.md juenger ist.
# 40_private: nur ordnernamen, ausser assistent (verfassungs-regel 8).

$ErrorActionPreference = 'SilentlyContinue'
$OD  = "$env:USERPROFILE\OneDrive"
$out = "$OD\00_System\STATE.md"

# --- staleness-guard ---
if (Test-Path $out) {
    $stateT = (Get-Item $out).LastWriteTime
    if (((Get-Date) - $stateT).TotalHours -lt 6) {
        $newer = @(Get-ChildItem "$OD\10_uni", "$OD\20_work", "$OD\30_venture", "$OD\50_career", "$OD\00_System" `
                -Recurse -Depth 2 -Filter 'CLAUDE.md' | Where-Object { $_.LastWriteTime -gt $stateT })
        $op2 = Get-Item "$OD\00_System\offene-punkte.md"
        if (-not $newer -and $op2.LastWriteTime -le $stateT) { exit }
    }
}

$areas = @(
    @{ dir = '10_uni' }, @{ dir = '20_work' }, @{ dir = '30_venture' },
    @{ dir = '40_private' }, @{ dir = '50_career' }, @{ dir = '00_System' }
)

# session-aktivitaet aus dem gemeinsamen index (copland-shared.ps1, EIN scan)
. "$OD\00_System\copland\copland-shared.ps1"
$idx = Get-CoplandIndex -Force
$sess = @{}
foreach ($prop in $idx.sessions.PSObject.Properties) {
    $sess[$prop.Name] = @{ newest = [datetime]$prop.Value.newest; s30 = [int]$prop.Value.s30 }
}

$L = New-Object System.Collections.Generic.List[string]
$ruhend = @(); $kanten = @(); $fristen = @(); $ohneKontext = 0; $projekte = 0

foreach ($a in $areas) {
    foreach ($p in @(Get-ChildItem (Join-Path $OD $a.dir) -Directory |
            Where-Object { $_.Name -notmatch '^[_.]' } | Sort-Object Name)) {
        $projekte++
        $rel = "$($a.dir)/$($p.Name)"
        $privat = ($a.dir -eq '40_private' -and $p.Name -ne 'assistent')
        $cmd = Join-Path $p.FullName 'CLAUDE.md'
        $alias = ''; $stand = ''; $status = ''
        if (-not $privat -and (Test-Path $cmd)) {
            $sec = ''
            foreach ($ln in (Get-Content $cmd -Encoding utf8)) {
                if ($ln -match '^##\s+(\S+)') { $sec = $Matches[1].ToLower(); continue }
                if ($ln -match 'alias:\s*([^|]+)') { $alias = $Matches[1].Trim() -replace '\s*,\s*', ',' }
                if ($ln -match 'status:\s*(\w+)') { $status = $Matches[1].ToLower() }
                if ($ln -match '^Verbunden:\s*(.+)') {
                    foreach ($ka in ($Matches[1] -split ';')) { $kanten += "$rel <-> $($ka.Trim())" }
                }
                if ($ln -match '^Frist:\s*(\d{4}-\d{2}-\d{2})\s*(.*)') {
                    $fristen += "$($Matches[1]) $($Matches[2]) ($rel)"
                }
                if ($sec -eq 'stand' -and $ln -match '^\s*-\s*(.+)') { $stand = $Matches[1] }
            }
        }
        # aktivitaet
        $sname = ($p.FullName -replace '[:\\_]', '-').ToLower()
        $d = 999; $s30 = 0
        if ($sess.ContainsKey($sname)) {
            $d = [int]((Get-Date) - $sess[$sname].newest).TotalDays
            $s30 = $sess[$sname].s30
        } elseif (Test-Path $cmd) {
            $d = [int]((Get-Date) - (Get-Item $cmd).LastWriteTime).TotalDays
        }
        if ($privat) {
            $ruhend += "$rel (privat)"
            continue
        }
        if (-not (Test-Path $cmd)) { $stand = 'KEIN-KONTEXT'; $ohneKontext++ }
        if ($status -eq 'archiv' -or ($d -gt 90 -and $s30 -eq 0)) {
            $ruhend += $rel
            continue
        }
        if ($stand.Length -gt 100) { $stand = $stand.Substring(0, 99) + '~' }
        $aliasStr = if ($alias) { "zuruf:$alias" } else { '' }
        $L.Add(('{0,-34} {1,-28} d{2,-4} s{3,-3} {4}' -f $rel, $aliasStr, $d, $s30, $stand))
    }
}

$B = New-Object System.Text.StringBuilder
[void]$B.AppendLine('# STATE -- maschinenzustand master-umgebung')
[void]$B.AppendLine('# GENERIERT von copland/copland-state.ps1 -- nicht von hand editieren.')
[void]$B.AppendLine('# spalten: pfad | zuruf | d=tage seit letzter session | s=sessions 30d | letzter stand')
[void]$B.AppendLine('# KEIN-KONTEXT = projekt ohne CLAUDE.md (beim naechsten arbeiten dort anlegen)')
[void]$B.AppendLine('')
[void]$B.AppendLine('[meta]')
[void]$B.AppendLine("generiert=$(Get-Date -Format 'yyyy-MM-dd HH:mm') projekte=$projekte ohne-kontext=$ohneKontext")
[void]$B.AppendLine('')
[void]$B.AppendLine('[projekte]')
foreach ($ln in $L) { [void]$B.AppendLine($ln) }
[void]$B.AppendLine('')
if ($ruhend) {
    [void]$B.AppendLine('[ruhend] (>90d ohne session oder privat/archiv -- nur pfade)')
    [void]$B.AppendLine(($ruhend -join ', '))
    [void]$B.AppendLine('')
}
if ($kanten) {
    [void]$B.AppendLine('[verbindungen]')
    foreach ($ka in ($kanten | Sort-Object -Unique)) { [void]$B.AppendLine($ka) }
    [void]$B.AppendLine('')
}
if ($fristen) {
    [void]$B.AppendLine('[fristen]')
    foreach ($fr in ($fristen | Sort-Object)) { [void]$B.AppendLine($fr) }
    [void]$B.AppendLine('')
}
# erinnerungen des assistenten als fristen-quelle
$erin = "$OD\40_private\assistent\erinnerungen.md"
if (Test-Path $erin) {
    $eLines = @(Get-Content $erin -Encoding utf8 | Where-Object { $_ -match '^\s*-\s*\[(\d{4}-\d{2}-\d{2})\]' })
    if ($eLines) {
        [void]$B.AppendLine('[erinnerungen] (aus 40_private/assistent/erinnerungen.md)')
        foreach ($el in $eLines) { [void]$B.AppendLine(($el -replace '^\s*-\s*', '')) }
        [void]$B.AppendLine('')
    }
}
[void]$B.AppendLine('[offen] (top je abschnitt, volltext: 00_System/offene-punkte.md)')
$sec = ''; $secCount = 0
foreach ($ln in (Get-Content "$OD\00_System\offene-punkte.md" -Encoding utf8)) {
    if ($ln -match '^##\s+(.*)') { $sec = $Matches[1].ToLower(); $secCount = 0 }
    elseif ($sec -and $secCount -lt 2 -and $ln -match '^\s*-\s*(.+)') {
        $t = $Matches[1]; if ($t.Length -gt 90) { $t = $t.Substring(0, 89) + '~' }
        [void]$B.AppendLine("$($sec -replace ' .*','') $t")
        $secCount++
    }
}
[void]$B.AppendLine('')
[void]$B.AppendLine('[system]')
$lastCommit = git -C "$OD\00_System" log -1 --pretty=format:'%h %ad %s' --date=format:'%d.%m.%H:%M'
[void]$B.AppendLine("git 00_System: $lastCommit")

Set-Content $out $B.ToString() -Encoding utf8
Write-Output "state -> $out ($([math]::Round($B.Length/1kb,1)) kb)"
