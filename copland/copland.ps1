# COPLAND OS — Launcher (Master-Umgebung Marko)
# Aufgerufen vom Windows-Terminal-Profil "COPLAND OS"
# workflow: menue -> bereich -> session | ^ = neuer tab | alt+links/rechts = tab-switch

$ErrorActionPreference = 'SilentlyContinue'
$OD = "$env:USERPROFILE\OneDrive"

# Farben (kaltes Blaugrau) -- gemeinsam mit dem panel
. "$OD\00_System\copland\copland-shared.ps1"

# kurze warnung im copland-ton -- fehler sollen hoerbar sein, nicht stumm versickern
function Warn([string]$msg) {
    Write-Host ""
    Write-Host "$WARN  copland: $msg$R"
    Start-Sleep -Milliseconds 1500
}

# --- digital rain (unten rechts, sparsam und gedimmt -- laeuft bis tastendruck) ---
$RainW = 40; $RainH = 14
$RainMinX = 48   # im menue: nicht in die menuespalte laufen ([w] setzt das um)
$RainChars = [char[]]'abcdefghikmnopqrstuvwxyz0123456789:.*+-='
$RainDrops = New-Object System.Collections.ArrayList
$RainTick  = 0
function Step-Rain {
    $win = $Host.UI.RawUI.WindowSize
    $x0 = $win.Width - $RainW - 2
    $y0 = $win.Height - $RainH - 1
    if ($x0 -lt $script:RainMinX -or $y0 -lt 2) { return }   # kein platz
    $script:RainTick++
    # nachschub: wenige tropfen, zufaellig
    if ($script:RainDrops.Count -lt 9 -and (Get-Random -Maximum 100) -lt 35) {
        [void]$script:RainDrops.Add(@{
            x = Get-Random -Maximum $RainW; y = 0
            len = 4 + (Get-Random -Maximum 5)
            slow = ((Get-Random -Maximum 2) -eq 0)
            chars = New-Object System.Collections.ArrayList
        })
    }
    $grid = @{}
    $dead = @()
    foreach ($d in $script:RainDrops) {
        if (-not ($d.slow -and ($script:RainTick % 2))) {
            $d.chars.Insert(0, $script:RainChars[(Get-Random -Maximum $script:RainChars.Count)])
            while ($d.chars.Count -gt $d.len) { $d.chars.RemoveAt($d.chars.Count - 1) }
            $d.y++
        }
        for ($i = 0; $i -lt $d.chars.Count; $i++) {
            $yy = $d.y - 1 - $i
            if ($yy -ge 0 -and $yy -lt $RainH) { $grid["$($d.x),$yy"] = @($d.chars[$i], ($i -eq 0)) }
        }
        if ($d.y - $d.len -gt $RainH) { $dead += $d }
    }
    foreach ($d in $dead) { $script:RainDrops.Remove($d) }
    $out = "$E[s"
    for ($yy = 0; $yy -lt $RainH; $yy++) {
        $line = ''
        for ($xx = 0; $xx -lt $RainW; $xx++) {
            $c = $grid["$xx,$yy"]
            if ($c) {
                # kopf im akzent, schweif gedimmt
                $line += if ($c[1]) { "$AC$($c[0])$DIM" } else { "$($c[0])" }
            } else { $line += ' ' }
        }
        $out += "$E[$($y0 + $yy);$($x0)H$DIM$line$R"
    }
    Write-Host -NoNewline "$out$E[u"
}

# --- Panel rechts (uhr + limits) ---
Clear-Host
if ($env:WT_SESSION -and -not $env:COPLAND_NO_PANEL) {
    # -p: panel erbt das schwarze copland-profil (sonst default-grau)
    # eigenes panel-profil: schwarz wie das hauptprofil, aber departure mono
    wt -w 0 split-pane -p "COPLAND PANEL" --vertical --size 0.2 powershell -NoLogo -NoProfile -ExecutionPolicy Bypass -File "$OD\00_System\copland\copland-panel.ps1"
    # fokus zweimal zurueckholen: faengt auch langsame pane-starts (move-focus ganz links = no-op)
    Start-Sleep -Milliseconds 500
    wt -w 0 move-focus left
    Start-Sleep -Milliseconds 700
    wt -w 0 move-focus left
}

# STATE.md aktualisieren (eigener prozess, staleness-guard macht es billig)
Start-Process -WindowStyle Hidden powershell -ArgumentList '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "$OD\00_System\copland\copland-state.ps1"

# ziffer = ordner-dekade (1=10, 2=20, ...), [s] = systemraum
$areas = @(
    @{ key='1'; label='UNI    '; dir='10_uni' },
    @{ key='2'; label='WORK   '; dir='20_work' },
    @{ key='3'; label='VENTURE'; dir='30_venture' },
    @{ key='4'; label='PRIVATE'; dir='40_private' },
    @{ key='5'; label='CAREER '; dir='50_career' },
    @{ key='s'; label='SYSTEM '; dir='00_System' }
)

# puls je bereich: wann lief dort zuletzt eine claude-session?
# ** = heute, * = gestern, . = diese woche, leer = ruht
function Get-AreaPulse {
    $p = @{}
    Get-ChildItem "$env:USERPROFILE\.claude\projects" -Directory | ForEach-Object {
        $n = $_.Name -replace '^[Cc]--Users-marep-OneDrive-', ''
        # neueste session-DATEI zaehlt, nicht das ordner-datum (laufende sessions!)
        $newest = @(Get-ChildItem $_.FullName -File -Filter *.jsonl |
            Sort-Object LastWriteTime -Descending | Select-Object -First 1)
        if (-not $newest) { return }
        foreach ($ar in $script:areas) {
            $pref = $ar.dir -replace '_', '-'
            if ($n -like "$pref*") {
                if (-not $p[$ar.dir] -or $newest[0].LastWriteTime -gt $p[$ar.dir]) { $p[$ar.dir] = $newest[0].LastWriteTime }
            }
        }
    }
    $marks = @{}
    foreach ($ar in $script:areas) {
        $t = $p[$ar.dir]
        $marks[$ar.dir] = if (-not $t) { '' }
            elseif ($t.Date -eq (Get-Date).Date) { '**' }
            elseif ($t.Date -eq (Get-Date).Date.AddDays(-1)) { '*' }
            elseif ($t -gt (Get-Date).AddDays(-7)) { '.' }
            else { '' }
    }
    $marks
}

# balance: wie viele claude-sessions je lebensbereich in den letzten 7 tagen
function Get-AreaBalance {
    $bal = [ordered]@{}
    foreach ($ba in $script:areas) { $bal[$ba.dir] = 0 }
    Get-ChildItem "$env:USERPROFILE\.claude\projects" -Directory | ForEach-Object {
        $bn = $_.Name -replace '^[Cc]--Users-marep-OneDrive-', ''
        foreach ($ba in $script:areas) {
            if ($bn -like "$(($ba.dir -replace '_', '-'))*") {
                $bal[$ba.dir] += @(Get-ChildItem $_.FullName -File -Filter *.jsonl |
                    Where-Object { $_.LastWriteTime -gt (Get-Date).AddDays(-7) }).Count
            }
        }
    }
    $bal
}

# aktivitaet pro tag (anzahl beruehrter sessions), fuer die heatmap
function Get-DayActivity([int]$days = 112) {
    $act = @{}
    Get-ChildItem "$env:USERPROFILE\.claude\projects" -Directory | ForEach-Object {
        Get-ChildItem $_.FullName -File -Filter *.jsonl | ForEach-Object {
            if ($_.LastWriteTime -gt (Get-Date).AddDays(-$days)) {
                $d = $_.LastWriteTime.Date.ToString('yyyy-MM-dd')
                $act[$d] = [int]$act[$d] + 1
            }
        }
    }
    $act
}

# sessions je bereich und woche (8 wochen, index 0 = aelteste), fuer sparklines
function Get-AreaWeekly {
    $w = @{}
    foreach ($ba in $script:areas) { $w[$ba.dir] = @(0) * 8 }
    Get-ChildItem "$env:USERPROFILE\.claude\projects" -Directory | ForEach-Object {
        $bn = $_.Name -replace '^[Cc]--Users-marep-OneDrive-', ''
        $adir = $null
        foreach ($ba in $script:areas) { if ($bn -like "$(($ba.dir -replace '_', '-'))*") { $adir = $ba.dir; break } }
        if (-not $adir) { return }
        Get-ChildItem $_.FullName -File -Filter *.jsonl | ForEach-Object {
            $ageW = [math]::Floor(((Get-Date) - $_.LastWriteTime).TotalDays / 7)
            if ($ageW -ge 0 -and $ageW -lt 8) { $w[$adir][7 - $ageW]++ }
        }
    }
    $w
}

function Show-Menu {
    $Host.UI.RawUI.WindowTitle = 'COPLAND OS'
    Clear-Host
    Write-Host ""
    Write-Host "$DIM  .......................................$R"
    Write-Host ""
    Write-Host "$AC   COPLAND OS$R"
    Write-Host "$DIM   present day. present time.$R"
    Write-Host ""
    Write-Host "$DIM  .......................................$R"
    Write-Host ""
    # zwei spalten: links bereiche/orte, rechts tools -- halbe hoehe, ein raster
    $menuRows = @(
        @('1', 'UNI    ', '10_uni',     '0', 'shell'),
        @('2', 'WORK   ', '20_work',    'o', 'lokal'),
        @('3', 'VENTURE', '30_venture', 'i', 'status'),
        @('4', 'PRIVATE', '40_private', 'h', 'hub'),
        @('5', 'CAREER ', '50_career',  'u', 'usage'),
        @('s', 'SYSTEM ', '00_System',  'b', 'backup'),
        @('7', 'WERKST ', 'dokumente',  'm', 'manual'),
        @('a', 'ALLTAG ', 'briefing',   'q', 'beenden')
    )
    # laufvariable NICHT $r nennen -- ps-variablen sind case-insensitiv, $R ist der ansi-reset
    $pulse = Get-AreaPulse
    foreach ($mrow in $menuRows) {
        $mk = ''
        foreach ($ar in $areas) { if ($ar.dir -eq $mrow[2]) { $mk = $pulse[$ar.dir] } }
        Write-Host "$AC   [$($mrow[0])]$R$FG $($mrow[1])$R$DIM  $($mrow[2].PadRight(11))$($mk.PadRight(4))$R$AC[$($mrow[3])]$R$FG $($mrow[4])$R"
    }
    Write-Host ("$FG   " + (' ' * 28) + "$AC[w]$R$FG wired$R$DIM  ambient-monitor$R")
    Write-Host ""
    Write-Host "$DIM   ^ = neuer tab    alt+links/rechts = tab-switch$R"
    Write-Host ""
}

function Start-Claude([string]$dir, [string]$mode, [string]$area) {
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $exe = if ($mode -eq 'codex') { 'codex' } else { 'claude' }
    if (-not (Get-Command $exe -ErrorAction SilentlyContinue)) {
        Warn "$exe nicht gefunden"
        return
    }
    Set-Location $dir
    # tab-titel: bereich/projekt, damit alt+links/rechts zielgerichtet wird
    $leaf = Split-Path $dir -Leaf
    $title = if ($area -and $leaf -notmatch '^\d0_') { "$area/$leaf" } elseif ($area) { $area } else { $leaf }
    $Host.UI.RawUI.WindowTitle = $title
    Clear-Host
    Write-Host ""
    Write-Host "$DIM  copland: verbinde -> $leaf$R"
    Write-Host ""
    switch ($mode) {
        'continue' { claude --continue }
        'resume'   { claude --resume }
        'codex'    { codex }
        default    { claude }
    }
    # nach Claude-Ende zurueck ins Menue
}

while ($true) {
    Show-Menu
    Write-Host -NoNewline "$AC   > $R"
    # warten auf taste, dabei regnet es unten rechts
    while (-not [Console]::KeyAvailable) {
        Step-Rain
        Start-Sleep -Milliseconds 130
    }
    $k = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown').Character
    Write-Host $k

    if ("$k" -match '^[qQ]$') { exit }
    if ("$k" -match '^[oO]$') {
        Clear-Host
        Write-Host ""
        Write-Host "$AC   LOKAL$R$DIM  offline-ki, /bye beendet$R"
        Write-Host ""
        Write-Host "$AC   [enter]$R$FG gpt-oss 20b$R$DIM   allrounder, staerkstes$R"
        Write-Host "$AC   [2]$R$FG     qwen3 14b$R$DIM     allrounder, schneller$R"
        Write-Host "$AC   [3]$R$FG     gemma3 12b$R$DIM    kann auch bilder ansehen$R"
        Write-Host "$DIM   [z]     zurueck$R"
        Write-Host -NoNewline "$AC   > $R"
        $c = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown').Character
        Write-Host ""
        if ("$c" -match '^[zZ]$') { continue }
        if (-not (Get-Command ollama -ErrorAction SilentlyContinue)) {
            Warn 'ollama nicht gefunden'
            continue
        }
        $lm = 'gpt-oss:20b'
        if ("$c" -eq '2') { $lm = 'qwen3:14b' }
        elseif ("$c" -eq '3') { $lm = 'gemma3:12b' }
        $Host.UI.RawUI.WindowTitle = 'lokal'
        Clear-Host
        Write-Host ""
        Write-Host "$DIM  copland: lokal-modus ($lm, offline). /bye beendet.$R"
        Write-Host ""
        ollama run $lm
        continue
    }
    if ("$k" -match '^[bB]$') {
        Clear-Host
        Write-Host ""
        Write-Host "$AC   BACKUP$R$DIM  sichere configs nach onedrive ...$R"
        Write-Host ""
        $bk = "$OD\00_System\copland\backup\copland-backup.ps1"
        if (Test-Path $bk) { & $bk } else { Warn 'backup-skript nicht gefunden' }
        Write-Host ""
        Write-Host -NoNewline "$DIM  beliebige taste -> menue $R"
        [void]$Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
        continue
    }
    if ("$k" -match '^[aA]$') {
        # alltag: eigener ort fuer den personal assistant, startet direkt mit /briefing
        $adir = "$OD\40_private\assistent"
        if (-not (Test-Path $adir)) { New-Item -ItemType Directory -Path $adir -Force | Out-Null }
        if (-not (Get-Command claude -ErrorAction SilentlyContinue)) { Warn 'claude nicht gefunden'; continue }
        Set-Location $adir
        $Host.UI.RawUI.WindowTitle = 'alltag'
        Clear-Host
        Write-Host ""
        Write-Host "$DIM  copland: verbinde -> assistent$R"
        Write-Host ""
        claude "/briefing"
        continue
    }
    if ("$k" -match '^[wW]$') {
        # wired-monitor: vollbild-ambient (uhr + limits + rain), jede taste beendet
        $Host.UI.RawUI.WindowTitle = 'wired'
        $mwin = $Host.UI.RawUI.WindowSize
        $script:RainW = [math]::Max(30, $mwin.Width - 10)
        $script:RainH = [math]::Max(8, $mwin.Height - 12)
        $script:RainMinX = 4
        $script:RainDrops.Clear()
        Clear-Host
        $lastMin = -1
        while (-not [Console]::KeyAvailable) {
            $now = Get-Date
            if ($now.Minute -ne $lastMin) {
                $lastMin = $now.Minute
                $tstr = $now.ToString('HH:mm')
                $dstr = $now.ToString('ddd dd.MM.').ToLower()
                $lim = ''
                $mc = $null
                if (Test-Path "$env:LOCALAPPDATA\copland-limits.json") {
                    $mc = Get-Content "$env:LOCALAPPDATA\copland-limits.json" -Raw | ConvertFrom-Json
                }
                if ($mc) {
                    if ($null -ne $mc.five_hour.used_percentage) { $lim += "5h $([math]::Round($mc.five_hour.used_percentage))%" }
                    if ($null -ne $mc.seven_day.used_percentage) { $lim += "   7d $([math]::Round($mc.seven_day.used_percentage))%" }
                }
                if (Test-Path "$env:LOCALAPPDATA\copland-usage.json") {
                    $msc = @((Get-Content "$env:LOCALAPPDATA\copland-usage.json" -Raw | ConvertFrom-Json).limits |
                        Where-Object { $_.kind -eq 'weekly_scoped' -and $_.scope.model.display_name })
                    foreach ($ms in $msc) { $lim += "   $("$($ms.scope.model.display_name)".ToLower()) $([math]::Round($ms.percent))%" }
                }
                $cx2 = [int]($mwin.Width / 2)
                Write-Host -NoNewline "$E[3;1H$E[K$(' ' * [math]::Max(0, $cx2 - [int]($tstr.Length / 2)))$AC$tstr$R"
                Write-Host -NoNewline "$E[5;1H$E[K$(' ' * [math]::Max(0, $cx2 - [int]($dstr.Length / 2)))$DIM$dstr$R"
                Write-Host -NoNewline "$E[7;1H$E[K$(' ' * [math]::Max(0, $cx2 - [int]($lim.Length / 2)))$DIM$lim$R"
            }
            Step-Rain
            Start-Sleep -Milliseconds 120
        }
        [void]$Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
        $script:RainW = 40; $script:RainH = 14; $script:RainMinX = 48
        $script:RainDrops.Clear()
        continue
    }
    if ("$k" -match '^[iI]$') {
        Clear-Host
        Write-Host ""
        Write-Host "$AC   STATUS$R"
        Write-Host "$DIM   .....................................$R"
        Write-Host ""

        # zuletzt gearbeitet: wo tatsaechlich claude-sessions liefen
        Write-Host "$DIM   zuletzt gearbeitet$R"
        $map = [ordered]@{ '00-System'='system'; '10-uni'='uni'; '20-work'='work'; '30-venture'='venture'; '40-private'='private'; '50-career'='career' }
        Get-ChildItem "$env:USERPROFILE\.claude\projects" -Directory |
            Where-Object { $_.Name -match '^[Cc]--Users-marep-OneDrive-' } |
            Sort-Object LastWriteTime -Descending | Select-Object -First 7 | ForEach-Object {
                $n = $_.Name -replace '^[Cc]--Users-marep-OneDrive-', ''
                foreach ($ak in $map.Keys) {
                    if ($n -like "$ak*") { $n = $map[$ak] + ($n.Substring($ak.Length) -replace '^-', '/'); break }
                }
                $lw = $_.LastWriteTime
                $rel = if ($lw.Date -eq (Get-Date).Date) { 'heute' }
                       elseif ($lw.Date -eq (Get-Date).Date.AddDays(-1)) { 'gestern' }
                       else { "vor $([int]((Get-Date) - $lw).TotalDays)t" }
                if ($n.Length -gt 30) { $n = $n.Substring(0, 29) + '~' }
                Write-Host "$FG   $($n.PadRight(31))$R$DIM $rel$R"
            }
        Write-Host ""

        # heatmap: aktivitaet pro tag, letzte 16 wochen (spalte = woche)
        $act = Get-DayActivity 112
        if ($act.Count -gt 0) {
            Write-Host "$DIM   aktivitaet (16 wochen, . : + * #)$R"
            $today = (Get-Date).Date
            $monday = $today.AddDays(-(([int]$today.DayOfWeek + 6) % 7))
            $hstart = $monday.AddDays(-15 * 7)
            $names = 'mo', 'di', 'mi', 'do', 'fr', 'sa', 'so'
            for ($dw = 0; $dw -lt 7; $dw++) {
                $line = ''
                for ($wk = 0; $wk -lt 16; $wk++) {
                    $d = $hstart.AddDays($wk * 7 + $dw)
                    if ($d -gt $today) { $line += '  '; continue }
                    $v = [int]$act[$d.ToString('yyyy-MM-dd')]
                    $ch = if ($v -ge 7) { '#' } elseif ($v -ge 4) { '*' } elseif ($v -ge 2) { '+' } elseif ($v -ge 1) { ':' } else { '.' }
                    $line += "$ch "
                }
                Write-Host "$DIM   $($names[$dw]) $R$FG$line$R"
            }
            Write-Host ""
        }

        # balance: wohin floss die woche? (balken = 7 tage, sparkline = 8 wochen)
        $bal = Get-AreaBalance
        $wk8 = Get-AreaWeekly
        $balMax = ($bal.Values | Measure-Object -Maximum).Maximum
        if ($balMax -gt 0) {
            Write-Host "$DIM   balance (sessions 7 tage | verlauf 8 wochen)$R"
            $wkMax = 0
            foreach ($ba in $areas) { foreach ($v8 in $wk8[$ba.dir]) { if ($v8 -gt $wkMax) { $wkMax = $v8 } } }
            foreach ($ba in $areas) {
                $v = $bal[$ba.dir]
                $f = [math]::Round($v / $balMax * 10)
                $bc = ConvertTo-BrailleChart ([double[]]$wk8[$ba.dir]) 8 1 $wkMax
                $spark = if ($bc) { $bc[0] } else {
                    $s2 = ''
                    foreach ($v8 in $wk8[$ba.dir]) {
                        $s2 += if ($v8 -ge 6) { '#' } elseif ($v8 -ge 3) { '=' } elseif ($v8 -ge 1) { ':' } else { '.' }
                    }
                    $s2
                }
                Write-Host "$FG   $($ba.label.Trim().ToLower().PadRight(9))$R$DIM[$('=' * $f)$('.' * (10 - $f))] $v   $spark$R"
            }
            Write-Host ""
        }

        # meistgenutzte skills (eigene slash-commands, letzte 30 tage; builtins raus)
        $hist = "$env:USERPROFILE\.claude\history.jsonl"
        if (Test-Path $hist) {
            $builtin = '^(compact|clear|model|config|effort|voice|mobile|workflows|resume|fast|tasks|help|init|doctor|login|logout|status|cost|memory)$'
            $cut = [DateTimeOffset]::Now.AddDays(-30).ToUnixTimeMilliseconds()
            $top = Get-Content $hist | ForEach-Object {
                try { $j = $_ | ConvertFrom-Json } catch { return }
                if ($j.timestamp -ge $cut -and "$($j.display)" -match '^/(\S+)') {
                    if ($Matches[1] -notmatch $builtin) { $Matches[1] }
                }
            } | Group-Object | Sort-Object Count -Descending | Select-Object -First 5
            if ($top) {
                Write-Host "$DIM   meistgenutzte skills (30 tage)$R"
                foreach ($t in $top) { Write-Host "$FG   /$($t.Name.PadRight(30))$R$DIM $($t.Count)x$R" }
                Write-Host ""
            }
        }

        # offene punkte je abschnitt
        $op = "$OD\00_System\offene-punkte.md"
        if (Test-Path $op) {
            Write-Host "$DIM   offene punkte$R"
            $sec = ''; $counts = [ordered]@{}
            foreach ($line in Get-Content $op -Encoding utf8) {
                if ($line -match '^##\s+(.*)') { $sec = $Matches[1].ToLower(); $counts[$sec] = 0 }
                elseif ($sec -and $line -match '^\s*-\s') { $counts[$sec]++ }
            }
            foreach ($sk in $counts.Keys) {
                $sn = "$sk"
                if ($sn.Length -gt 30) { $sn = $sn.Substring(0, 29) + '~' }
                Write-Host "$FG   $($sn.PadRight(31))$R$DIM $($counts[$sk]) punkte$R"
            }
        }

        Write-Host ""
        Write-Host -NoNewline "$DIM  beliebige taste -> menue $R"
        [void]$Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
        continue
    }
    if ("$k" -match '^[hH]$') {
        # hub als dashboard: links bereiche/projekte, rechts verlauf + offen + skills
        Clear-Host
        $L  = New-Object System.Collections.Generic.List[object]
        $RC = New-Object System.Collections.Generic.List[object]
        $projTotal = 0; $heuteAktiv = 0
        foreach ($ar in $areas) {
            $adir = Join-Path $OD $ar.dir
            $projs = @(Get-ChildItem $adir -Directory | Where-Object { $_.Name -notmatch '^[_.]' } | Sort-Object Name)
            $projTotal += $projs.Count
            $L.Add(@{ t = $ar.label.Trim(); c = "$AC$($ar.label.Trim())$R" })
            foreach ($p in $projs) {
                $t = $p.LastWriteTime
                $cmdMd = Join-Path $p.FullName 'CLAUDE.md'
                if (Test-Path $cmdMd) { $ct = (Get-Item $cmdMd).LastWriteTime; if ($ct -gt $t) { $t = $ct } }
                if ($t.Date -eq (Get-Date).Date) { $heuteAktiv++ }
                $rel = if ($t.Date -eq (Get-Date).Date) { 'heute' }
                       elseif ($t.Date -eq (Get-Date).Date.AddDays(-1)) { 'gestern' }
                       else { "vor $([int]((Get-Date) - $t).TotalDays)t" }
                $n = $p.Name
                if ($n.Length -gt 19) { $n = $n.Substring(0, 18) + '~' }
                $L.Add(@{ t = "  $($n.PadRight(20))$rel"; c = "$FG  $($n.PadRight(20))$R$DIM$rel$R" })
            }
            $L.Add(@{ t = ''; c = '' })
        }
        $RC.Add(@{ t = 'ZULETZT'; c = "${AC}ZULETZT$R" })
        foreach ($gl in (git -C "$OD\00_System" log --pretty=format:'%ad  %s' --date=format:'%d.%m.' -8)) {
            $gls = "$gl"
            if ($gls.Length -gt 44) { $gls = $gls.Substring(0, 43) + '~' }
            $RC.Add(@{ t = " $gls"; c = "$DIM $gls$R" })
        }
        $RC.Add(@{ t = ''; c = '' })
        $op = "$OD\00_System\offene-punkte.md"
        if (Test-Path $op) {
            $RC.Add(@{ t = 'OFFEN'; c = "${AC}OFFEN$R" })
            $sec = ''; $counts = [ordered]@{}
            foreach ($line in Get-Content $op -Encoding utf8) {
                if ($line -match '^##\s+(.*)') { $sec = $Matches[1].ToLower(); $counts[$sec] = 0 }
                elseif ($sec -and $line -match '^\s*-\s') { $counts[$sec]++ }
            }
            foreach ($sk2 in $counts.Keys) {
                $sn = "$sk2"; if ($sn.Length -gt 34) { $sn = $sn.Substring(0, 33) + '~' }
                $RC.Add(@{ t = " $($sn.PadRight(35))$($counts[$sk2])"; c = "$FG $($sn.PadRight(35))$R$DIM$($counts[$sk2])$R" })
            }
            $RC.Add(@{ t = ''; c = '' })
        }
        $bal = Get-AreaBalance
        $balMax = ($bal.Values | Measure-Object -Maximum).Maximum
        if ($balMax -gt 0) {
            $RC.Add(@{ t = 'BALANCE'; c = "${AC}BALANCE$R" })
            foreach ($ba in $areas) {
                $v = $bal[$ba.dir]
                $f = [math]::Round($v / $balMax * 10)
                $bt = " $($ba.label.Trim().ToLower().PadRight(9))[$('=' * $f)$('.' * (10 - $f))] $v"
                $RC.Add(@{ t = $bt; c = "$FG $($ba.label.Trim().ToLower().PadRight(9))$R$DIM[$('=' * $f)$('.' * (10 - $f))] $v$R" })
            }
            $RC.Add(@{ t = ''; c = '' })
        }
        $RC.Add(@{ t = 'SKILLS'; c = "${AC}SKILLS$R" })
        $skl = @(Get-ChildItem "$env:USERPROFILE\.claude\skills" -Directory | ForEach-Object { "/$($_.Name)" }) +
               @(Get-ChildItem "$env:USERPROFILE\.claude\commands" -File -Filter *.md | ForEach-Object { "/$($_.BaseName)" })
        $lineBuf = ''
        foreach ($s2 in $skl) {
            if (($lineBuf + ' ' + $s2).Length -gt 44) { $RC.Add(@{ t = " $lineBuf"; c = "$DIM $lineBuf$R" }); $lineBuf = $s2 }
            else { $lineBuf = ($lineBuf + ' ' + $s2).Trim() }
        }
        if ($lineBuf) { $RC.Add(@{ t = " $lineBuf"; c = "$DIM $lineBuf$R" }) }

        Write-Host ""
        Write-Host "$AC   HUB$R$DIM   $($areas.Count) bereiche | $projTotal projekte | $heuteAktiv heute aktiv$R"
        Write-Host "$DIM   ...............................................................................$R"
        Write-Host ""
        $Lw = 32
        $max = [math]::Max($L.Count, $RC.Count)
        for ($i = 0; $i -lt $max; $i++) {
            # NICHT $lc/$rc nennen wie die listen -- ps-variablen sind case-insensitiv
            $cellL = if ($i -lt $L.Count) { $L[$i] } else { @{ t = ''; c = '' } }
            $cellR = if ($i -lt $RC.Count) { $RC[$i] } else { @{ t = ''; c = '' } }
            $pad = ' ' * [math]::Max(0, $Lw - $cellL.t.Length)
            Write-Host "   $($cellL.c)$pad$DIM|$R  $($cellR.c)"
        }
        Write-Host ""
        Write-Host -NoNewline "$DIM  [b] browser-version   beliebige taste -> menue $R"
        $c = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown').Character
        if ("$c" -match '^[bB]$') {
            & "$OD\00_System\copland\copland-hub.ps1" | Out-Null
            Start-Process "$OD\00_System\copland\hub.html"
        }
        continue
    }
    if ("$k" -match '^[uU]$') {
        Clear-Host
        Write-Host ""
        Write-Host "$AC   USAGE$R$DIM  tokens pro tag, letzte 14 tage$R"
        Write-Host ""
        $cuOk = $false
        if (Get-Command ccusage -ErrorAction SilentlyContinue) {
            try {
                $cuAll = @((ccusage daily --json 2>$null | ConvertFrom-Json).daily)
                $cu = @($cuAll | Select-Object -Last 14)
                $cuMax = ($cu | Measure-Object totalTokens -Maximum).Maximum
                if ($cuMax -gt 0) {
                    foreach ($cd in $cu) {
                        $f = [math]::Round($cd.totalTokens / $cuMax * 24)
                        $mt = [math]::Round($cd.totalTokens / 1e6, 1)
                        $dstr = ([datetime]$cd.period).ToString('dd.MM.')
                        Write-Host "$DIM   $dstr $R$FG[$('=' * $f)$('.' * (24 - $f))]$R$DIM $($mt)M tok | $([math]::Round($cd.totalCost)) usd$R"
                    }
                    # verlaufskurve (braille, 30 tage)
                    $curve = @($cuAll | Select-Object -Last 30 | ForEach-Object { [double]$_.totalTokens })
                    $bc = ConvertTo-BrailleChart $curve 32 4
                    if ($bc) {
                        Write-Host ""
                        Write-Host "$DIM   verlauf 30 tage$R"
                        foreach ($bl in $bc) { Write-Host "$AC   $bl$R" }
                    }
                    $cuOk = $true
                }
            } catch { }
            if (-not $cuOk) { ccusage }
        } else { Warn 'ccusage nicht gefunden' }
        Write-Host ""
        Write-Host -NoNewline "$DIM  [d] voller report   beliebige taste -> menue $R"
        $cuk = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown').Character
        if ("$cuk" -match '^[dD]$') {
            Clear-Host
            Write-Host ""
            ccusage
            Write-Host ""
            Write-Host -NoNewline "$DIM  beliebige taste -> menue $R"
            [void]$Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
        }
        continue
    }
    if ("$k" -match '^[mM]$') {
        Clear-Host
        Get-Content "$OD\00_System\copland\manual.md" | ForEach-Object {
            if ($_ -match '^[A-Z]') { Write-Host "$AC$_$R" } else { Write-Host "$FG$_$R" }
        }
        Write-Host ""
        Write-Host -NoNewline "$DIM  beliebige taste -> menue $R"
        [void]$Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
        continue
    }
    if ($k -eq '7') {
        $wdir = "$OD\00_System\werkstatt"
        while ($true) {
            Clear-Host
            Write-Host ""
            Write-Host "$AC   WERKSTATT$R"
            Write-Host "$DIM   ---------------------------------------$R"
            $files = @(Get-ChildItem "$wdir\html\*.html", "$wdir\pdf\*.pdf" -File) |
                Sort-Object LastWriteTime -Descending | Select-Object -First 9
            if ($files) {
                $i = 1
                foreach ($f in $files) {
                    $tag = $f.Extension.TrimStart('.') -replace 'html', 'htm'
                    $n = $f.BaseName
                    if ($n.Length -gt 28) { $n = $n.Substring(0, 27) + '~' }
                    # name auf feste breite -> tag und datum bilden rechte spalten
                    Write-Host "$AC   [$i]$R$FG $($n.PadRight(28))$R$DIM  $tag  $($f.LastWriteTime.ToString('dd.MM.'))$R"
                    $i++
                }
            } else {
                Write-Host "$DIM   (leer)$R"
            }
            Write-Host ""
            Write-Host "$DIM   [i] index im browser   [e] explorer   [z] zurueck$R"
            Write-Host -NoNewline "$AC   > $R"
            $c = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown').Character
            if ("$c" -match '^[zZ]$') { break }
            if ("$c" -match '^[iI]$') { Start-Process "$wdir\INDEX.html"; continue }
            if ("$c" -match '^[eE]$') { Start-Process explorer $wdir; continue }
            if ("$c" -match '^[1-9]$') {
                $idx = [int]"$c" - 1
                if ($files -and $idx -lt $files.Count) { Start-Process $files[$idx].FullName }
            }
        }
        continue
    }
    if ($k -eq '0') {
        Set-Location $OD
        Clear-Host
        Write-Host "$DIM  copland: shell-modus. 'exit' zurueck zum menue.$R"
        break
    }
    $sel = $areas | Where-Object { $_.key -eq "$k".ToLower() }
    if ($sel) {
        $base = Join-Path $OD $sel.dir

        # --- projekt-auswahl: enter = oberordner, ziffer = unterordner, n = neu, z = zurueck ---
        # alphabetisch sortiert: ziffer bleibt stabil, kein wandern nach aenderungsdatum
        $projs = @(Get-ChildItem $base -Directory |
            Where-Object { $_.Name -notmatch '^[_.]' } |
            Sort-Object Name | Select-Object -First 9)
        # bereichs-karte: je projekt letzte aktivitaet + stand aus der CLAUDE.md
        $cards = @()
        foreach ($p in $projs) {
            $t = $p.LastWriteTime
            $st = ''
            $privat = ($sel.dir -eq '40_private' -and $p.Name -ne 'assistent')
            $cmdMd = Join-Path $p.FullName 'CLAUDE.md'
            if (Test-Path $cmdMd) {
                $ct = (Get-Item $cmdMd).LastWriteTime
                if ($ct -gt $t) { $t = $ct }
                if (-not $privat) {
                    $sec = ''
                    foreach ($ml in (Get-Content $cmdMd -Encoding utf8)) {
                        if ($ml -match '^##\s+(\S+)') { $sec = $Matches[1].ToLower(); continue }
                        if ($sec -eq 'stand' -and $ml -match '^\s*-\s*(.+)') { $st = $Matches[1] }
                    }
                }
            }
            $rel = if ($t.Date -eq (Get-Date).Date) { 'heute' }
                   elseif ($t.Date -eq (Get-Date).Date.AddDays(-1)) { 'gestern' }
                   else { "vor $([int]((Get-Date) - $t).TotalDays)t" }
            if ($st.Length -gt 68) { $st = $st.Substring(0, 67) + '~' }
            $cards += , @{ n = $p.Name; rel = $rel; st = $st }
        }
        $heuteAktiv = @($cards | Where-Object { $_.rel -eq 'heute' }).Count

        $target = $null
        while ($true) {
            Clear-Host
            Write-Host ""
            Write-Host "$AC   $($sel.label.Trim())$R$DIM  $($projs.Count) projekte | $heuteAktiv heute aktiv$R"
            Write-Host ""
            $i = 1
            foreach ($cd in $cards) {
                $n = $cd.n
                if ($n.Length -gt 27) { $n = $n.Substring(0, 26) + '~' }
                Write-Host "$AC   [$i]$R$FG $($n.PadRight(28))$R$DIM$($cd.rel)$R"
                if ($cd.st) { Write-Host "$DIM       stand: $($cd.st)$R" }
                $i++
            }
            if ($projs) { Write-Host "" }
            Write-Host "$DIM   [enter] ganzer bereich    [n] neues projekt    [z] zurueck$R"
            Write-Host -NoNewline "$AC   > $R"
            $pk = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown').Character
            Write-Host ""
            if ("$pk" -match '^[zZ]$') { break }
            if ($pk -eq [char]13) { $target = $base; break }
            if ("$pk" -match '^[1-9]$') {
                $idx = [int]"$pk" - 1
                if ($idx -lt $projs.Count) { $target = $projs[$idx].FullName; break }
            } elseif ("$pk" -match '^[nN]$') {
                Write-Host -NoNewline "$AC   name > $R"
                $pname = Read-Host
                if ($pname) {
                    $target = Join-Path $base $pname
                    New-Item -ItemType Directory -Path $target -Force | Out-Null
                    if (-not (Test-Path $target)) {
                        Warn "projektordner konnte nicht angelegt werden: $pname"
                        $target = $null
                        continue
                    }
                    $cmd = Join-Path $target 'CLAUDE.md'
                    if (-not (Test-Path $cmd)) {
                        @(
                            "# $pname -- Projektkontext"
                            ""
                            "Bereich: $($sel.label.Trim()). Angelegt: $(Get-Date -Format 'yyyy-MM-dd')."
                            ""
                            "## Zweck"
                            "(in der ersten session fuellen)"
                            ""
                            "## Stand"
                            "- neu angelegt"
                            ""
                            "## Regeln"
                            "- diese datei aktuell halten: nach jeder session Stand kurz ergaenzen"
                        ) | Set-Content $cmd -Encoding utf8
                    }
                    break
                }
            }
            # jede andere taste: menue neu zeichnen, nichts passiert stillschweigend
        }
        if (-not $target) { continue }

        # --- session-menue: enter/r/s/c starten, z zurueck, alles andere wird ignoriert ---
        $mode = $null
        while ($true) {
            Clear-Host
            Write-Host ""
            Write-Host "$DIM  copland: verbinde -> $(Split-Path $target -Leaf)$R"
            Write-Host ""
            Write-Host "$AC   [enter]$R$FG claude neu$R$DIM    [r] letzte    [s] session-liste    [c] chatgpt    [z] zurueck$R"
            Write-Host -NoNewline "$AC   > $R"
            $m = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown').Character
            Write-Host ""
            if ("$m" -match '^[zZ]$') { break }
            if ($m -eq [char]13)     { $mode = 'new'; break }
            if ("$m" -match '^[rR]$') { $mode = 'continue'; break }
            if ("$m" -match '^[sS]$') { $mode = 'resume'; break }
            if ("$m" -match '^[cC]$') { $mode = 'codex'; break }
        }
        if ($mode) { Start-Claude $target $mode $sel.label.Trim().ToLower() }
    }
}
