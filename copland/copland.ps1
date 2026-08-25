# COPLAND OS -- Launcher
# windows: windows-terminal-profil "COPLAND OS" | macos/linux: wezterm (default_prog) oder pwsh -File
# workflow: menue -> bereich -> session | ^ = neuer tab | alt+links/rechts = tab-switch

$ErrorActionPreference = 'SilentlyContinue'

# Farben + plattform ($OD, $IsWin, $PSExe) -- gemeinsam mit dem panel
. (Join-Path $PSScriptRoot 'copland-shared.ps1')

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

# --- Panel rechts (uhr + limits): terminal wird erkannt, kein setup noetig ---
# windows terminal -> wt split-pane | wezterm (macos/linux/win) -> wezterm cli |
# tmux -> split-window | sonst (iterm2, terminal.app, ...): panel von hand starten (manual)
Clear-Host
$panelPs = Join-Path $CoplandDir 'copland-panel.ps1'
if (-not $env:COPLAND_NO_PANEL) {
    if ($env:WT_SESSION -and (Get-Command wt -ErrorAction SilentlyContinue)) {
        # -p: eigenes panel-profil (schwarz wie das hauptprofil, departure mono)
        wt -w 0 split-pane -p "COPLAND PANEL" --vertical --size 0.2 powershell -NoLogo -NoProfile -ExecutionPolicy Bypass -File $panelPs
        # fokus zweimal zurueckholen: faengt auch langsame pane-starts (move-focus ganz links = no-op)
        Start-Sleep -Milliseconds 500
        wt -w 0 move-focus left
        Start-Sleep -Milliseconds 700
        wt -w 0 move-focus left
    } elseif ($env:WEZTERM_PANE -and (Get-Command wezterm -ErrorAction SilentlyContinue)) {
        $null = & wezterm cli split-pane --right --percent 20 -- $PSExe -NoLogo -NoProfile -File $panelPs
        Start-Sleep -Milliseconds 400
        $null = & wezterm cli activate-pane-direction left
    } elseif ($env:TMUX -and (Get-Command tmux -ErrorAction SilentlyContinue)) {
        & tmux split-window -h -p 20 -d "$PSExe -NoLogo -NoProfile -File '$panelPs'"
    }
}

# STATE.md aktualisieren (eigener prozess, staleness-guard macht es billig)
Start-Hidden (Join-Path $CoplandDir 'copland-state.ps1')
# tagesstart-ernte: 1x pro tag (marker im cache) destilliert claude -p die sessions von
# gestern ins brain (60_assistent/brain) -- ereignis statt uhrzeit, laptop ist sonst aus
if (-not (Test-Path (Join-Path $CacheDir ("copland-tagesstart-" + (Get-Date).ToString('yyyy-MM-dd'))))) {
    Start-Hidden (Join-Path $CoplandDir 'copland-ernte.ps1')
}

# ziffer = ordner-dekade (1=10, 2=20, ...), [s] = systemraum
$areas = @(
    @{ key='1'; label='UNI    '; dir='10_uni' },
    @{ key='2'; label='WORK   '; dir='20_work' },
    @{ key='3'; label='VENTURE'; dir='30_venture' },
    @{ key='4'; label='PRIVATE'; dir='40_private' },
    @{ key='5'; label='CAREER '; dir='50_career' },
    @{ key='s'; label='SYSTEM '; dir='00_System' },
    @{ key='a'; label='ASSIST '; dir='60_assistent'; self=$true }   # self = bereich ist selbst das projekt; puls/stats; [a] startet direkt (eigener zweig)
)

# bereichs-statistik aus dem gemeinsamen index (EIN scan, gecacht -- copland-shared.ps1)
function Get-AreaStats {
    $idx = Get-CoplandIndex
    $stats = @{}
    foreach ($ar in $script:areas) { $stats[$ar.dir] = @{ newest = $null; s7 = 0 } }
    foreach ($prop in $idx.sessions.PSObject.Properties) {
        $n = $prop.Name.ToLower() -replace ('^' + [regex]::Escape($ODMangled)), ''
        foreach ($ar in $script:areas) {
            if ($n -like "$(($ar.dir -replace '_', '-').ToLower())*") {
                $t = [datetime]$prop.Value.newest
                if (-not $stats[$ar.dir].newest -or $t -gt $stats[$ar.dir].newest) { $stats[$ar.dir].newest = $t }
                $stats[$ar.dir].s7 += [int]$prop.Value.s7
            }
        }
    }
    $stats
}

# puls je bereich: ** = heute, * = gestern, . = diese woche, leer = ruht
function Get-AreaPulse {
    $stats = Get-AreaStats
    $marks = @{}
    foreach ($ar in $script:areas) {
        $t = $stats[$ar.dir].newest
        $marks[$ar.dir] = if (-not $t) { '' }
            elseif ($t.Date -eq (Get-Date).Date) { '**' }
            elseif ($t.Date -eq (Get-Date).Date.AddDays(-1)) { '*' }
            elseif ($t -gt (Get-Date).AddDays(-7)) { '.' }
            else { '' }
    }
    $marks
}

# letzte session ueber alle bereiche: aus dem gecachten index (kein extra scan).
# mangled name (c--users-...-onedrive-10-uni-foo) -> echter pfad: unter $OD ebene fuer ebene
# das kind suchen, dessen mangled name praefix des rests ist.
function Get-LastSession {
    $idx = Get-CoplandIndex
    $best = $null; $bestT = [datetime]::MinValue
    foreach ($prop in $idx.sessions.PSObject.Properties) {
        $n = $prop.Name.ToLower()
        if (-not $n.StartsWith($ODMangled)) { continue }
        $t = [datetime]$prop.Value.newest
        if ($t -gt $bestT) { $bestT = $t; $best = $n.Substring($ODMangled.Length) }
    }
    if (-not $best) { return $null }
    $path = $OD; $rest = $best
    while ($rest) {
        $hit = $null
        foreach ($ch in (Get-ChildItem $path -Directory -ErrorAction SilentlyContinue | Sort-Object { $_.Name.Length } -Descending)) {
            $m = ($ch.Name -replace '[^A-Za-z0-9]', '-').ToLower()
            if ($rest -eq $m -or $rest.StartsWith($m + '-')) { $hit = $ch; break }
        }
        if (-not $hit) { return $null }
        $path = $hit.FullName
        $rest = if ($rest.Length -gt $hit.Name.Length) { $rest.Substring($hit.Name.Length + 1) } else { '' }
    }
    $areaLbl = ''
    foreach ($ar in $script:areas) { if ($path -like (Join-Path $OD $ar.dir) + '*') { $areaLbl = $ar.label.Trim() } }
    $leaf = Split-Path $path -Leaf
    $title = if ($areaLbl -and $leaf -notmatch '^\d0_') { "$areaLbl / $leaf" } elseif ($areaLbl) { $areaLbl } else { $leaf }
    $mins = [int]((Get-Date) - $bestT).TotalMinutes
    $ago = if ($mins -lt 60) { "vor ${mins}m" } elseif ($mins -lt 1440) { "vor $([int]($mins/60))h" } else { "vor $([int]($mins/1440))t" }
    @{ path = $path; area = $areaLbl; title = $title; ago = $ago }
}

# einheitliches screen-ende: [z] zurueck (kein 'beliebige taste' mehr)
function Wait-Back {
    Write-Host ""
    Write-Host -NoNewline "$DIM  [z] zurueck $R"
    while ($true) {
        $wb = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown').Character
        if ("$wb" -match '^[zZ]$') { return }
    }
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
    # drei spalten: lebensbereiche (ebene 2) | werkzeuge (ebene 1: system, mcp, assistent, werkstatt, hub, vault...) | ambient
    $pulse = Get-AreaPulse
    $bcol = @(
        @('1', 'UNI',     '10_uni'),
        @('2', 'WORK',    '20_work'),
        @('3', 'VENTURE', '30_venture'),
        @('4', 'PRIVATE', '40_private'),
        @('5', 'CAREER',  '50_career'),
        @('6', 'WERKST',  'dokumente')
    )
    $wcol = @(
        @('a', 'ALLTAG',  '60_assistent'),
        @('h', 'hub',     ''),
        @('v', 'vault',   '')
    )
    $acol = @(
        @('s', 'SYSTEM',  '00_System'),
        @('p', 'MCP',     '70_mcp'),
        @('c', 'chats',   ''),
        @('b', 'backup',  ''),
        @('m', 'manual',  '')
    )
    $mcol = @(@('u', 'musik'), @('w', 'wired'), @('o', 'lokal'), @('0', 'shell'), @('q', 'beenden'))
    # zelle: [k] LABEL    ordner        puls   -- feste breite in sichtbaren zeichen (farbcodes zaehlen nicht)
    $cell = {
        param($k, $lbl, $d, $mk, $w)
        $vis = 4 + 9 + 14 + 2
        $txt = "$AC[$k]$R$FG $($lbl.PadRight(8))$R$DIM $($d.PadRight(14))$R$AC$($mk.PadRight(2))$R"
        $txt + (' ' * [Math]::Max(0, $w - $vis))
    }
    $cw = @(33, 33, 33)
    Write-Host ($DIM + '   ' + 'lebensbereiche'.PadRight($cw[0]) + 'werkzeuge'.PadRight($cw[1]) + 'admin'.PadRight($cw[2]) + 'ambient' + $R)
    Write-Host ""
    $cols = @($bcol, $wcol, $acol)
    $rows = [Math]::Max([Math]::Max($bcol.Count, $wcol.Count), [Math]::Max($acol.Count, $mcol.Count))
    for ($mi = 0; $mi -lt $rows; $mi++) {
        $line = '   '
        for ($ci = 0; $ci -lt 3; $ci++) {
            $col = $cols[$ci]
            if ($mi -lt $col.Count) {
                $it = $col[$mi]; $mk = ''
                foreach ($ar in $areas) { if ($ar.dir -eq $it[2]) { $mk = $pulse[$ar.dir] } }
                $line += & $cell $it[0] $it[1] $it[2] $mk.Trim() $cw[$ci]
            } else { $line += ' ' * $cw[$ci] }
        }
        if ($mi -lt $mcol.Count) { $line += "$AC[$($mcol[$mi][0])]$R$FG $($mcol[$mi][1])$R" }
        Write-Host $line
    }
    Write-Host ""
    $last = Get-LastSession
    if ($last) {
        Write-Host "$AC   [enter]$R$FG weiter: $($last.title)$R$DIM   $($last.ago)$R"
        Write-Host ""
    }
    Write-Host "$DIM   ** heute   * gestern   . diese woche        ^ = neuer tab    alt+links/rechts = tab-switch$R"
    Write-Host ""
}

# werkstatt-browser: ordner zuerst, dann dateien (neueste oben). ziffer = rein/oeffnen, [+] naechste seite,
# [e] explorer (maus) im aktuellen ordner, [z] eine ebene hoch. ordner mit stundenzettel.ps1 bieten [n] = monat bauen.
function Show-Folder([string]$dir, [string]$root) {
    $page = 0
    while ($true) {
        Clear-Host
        $rel = $dir.Substring($root.Length).TrimStart('\', '/')
        Write-Host ""
        Write-Host "$AC   WERKSTATT$R$DIM  $(if ($rel) { "\$rel" } else { '(wurzel)' })$R"
        Write-Host "$DIM   ---------------------------------------$R"
        $dirs  = @(Get-ChildItem $dir -Directory | Where-Object { $_.Name -notmatch '^\.' } |
                   Sort-Object @{ e = { $_.Name.StartsWith('_') } }, Name)
        $files = @(Get-ChildItem $dir -File | Where-Object { $_.Name -notmatch '^(\.|CLAUDE\.md$|_index-neu|INDEX\.html$)' } |
                   Sort-Object Name -Descending)
        $items = @($dirs) + @($files)
        $pages = [Math]::Max(1, [Math]::Ceiling($items.Count / 9))
        if ($page -ge $pages) { $page = 0 }
        $shown = @($items | Select-Object -Skip ($page * 9) -First 9)
        if (-not $shown) { Write-Host "$DIM   (leer)$R" }
        $i = 1
        foreach ($it in $shown) {
            $n = $it.Name; if ($n.Length -gt 34) { $n = $n.Substring(0, 33) + '~' }
            if ($it.PSIsContainer) {
                $cnt = @(Get-ChildItem $it.FullName -File -Recurse).Count
                Write-Host "$AC   [$i]$R$FG $($n.PadRight(34))$R$DIM  ordner  $cnt dateien$R"
            } else {
                $tag = $it.Extension.TrimStart('.').ToLower() -replace 'html', 'htm'
                Write-Host "$AC   [$i]$R$FG $($n.PadRight(34))$R$DIM  $($tag.PadRight(5)) $($it.LastWriteTime.ToString('dd.MM.yy'))$R"
            }
            $i++
        }
        $gen = Join-Path $dir 'stundenzettel.ps1'
        Write-Host ""
        $keys = ''
        if ($pages -gt 1) { $keys += "[+] seite $($page + 1)/$pages   " }
        if (Test-Path $gen) { $keys += "[n] monat bauen   " }
        Write-Host "$DIM   $keys[i] index im browser (maus)   [e] explorer   [z] zurueck$R"
        Write-Host -NoNewline "$AC   > $R"
        $c = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown').Character
        if ("$c" -match '^[zZ]$') { break }
        if ("$c" -eq '+') { $page++; continue }
        if ("$c" -match '^[iI]$') { & (Join-Path $root '_index-neu.ps1') | Out-Null; Open-Item (Join-Path $root 'INDEX.html'); continue }
        if ("$c" -match '^[eE]$') { if ($IsWin) { Start-Process explorer $dir } else { Open-Item $dir }; continue }
        if ("$c" -match '^[nN]$' -and (Test-Path $gen)) {
            Write-Host ""
            Write-Host -NoNewline "$AC   monat (jjjj-mm, enter = aktueller): $R"
            $mon = (Read-Host).Trim()
            if (-not $mon) { $mon = (Get-Date).ToString('yyyy-MM') }
            $txt = Join-Path $dir "monate\$mon.txt"
            if (-not (Test-Path $txt)) {
                Warn "eingabe fehlt: monate\$mon.txt -- erst anlegen (zeile: jjjj-mm-tt hh:mm-hh:mm kommentar)"
                Wait-Back; continue
            }
            try { & $gen -Monat $mon -Oeffnen } catch { Warn "$_" }
            Wait-Back; continue
        }
        if ("$c" -match '^[1-9]$') {
            $idx = [int]"$c" - 1
            if ($idx -lt $shown.Count) {
                $it = $shown[$idx]
                if ($it.PSIsContainer) { Show-Folder $it.FullName $root; $page = 0 } else { Open-Item $it.FullName }
            }
        }
    }
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
    if ($k -eq [char]13) {
        $last = Get-LastSession
        if ($last) { Start-Claude $last.path 'continue' $last.area }
        continue
    }
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
    if ("$k" -match '^[cC]$') {
        # chats: alle claude-code-sessions, fortsetzen / loeschen (papierkorb)
        & (Join-Path $CoplandDir 'copland-chats.ps1')
        continue
    }
    if ("$k" -match '^[vV]$') {
        # vault: wissens-notizen im terminal (markdown + wikilinks, obsidian-kompatibel)
        & (Join-Path $CoplandDir 'copland-vault.ps1')
        continue
    }
    if ("$k" -match '^[uU]$') {
        # musik: spotify-player (media-session, kein api-key). q kehrt zurueck.
        & (Join-Path $CoplandDir 'copland-spotify.ps1')
        continue
    }
    if ("$k" -match '^[bB]$') {
        Clear-Host
        Write-Host ""
        Write-Host "$AC   BACKUP$R$DIM  sichere configs nach onedrive ...$R"
        Write-Host ""
        $bk = Join-Path $CoplandDir 'backup/copland-backup.ps1'
        if (Test-Path $bk) { & $bk } else { Warn 'backup-skript nicht gefunden' }
        Wait-Back
        continue
    }
    if ("$k" -match '^[aA]$') {
        # alltag: eigener ort fuer den personal assistant, startet direkt mit /briefing
        $adir = Join-Path $OD '60_assistent'
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
                $limF = Join-Path $CacheDir 'copland-limits.json'
                if (Test-Path $limF) { $mc = Get-Content $limF -Raw | ConvertFrom-Json }
                if ($mc) {
                    if ($null -ne $mc.five_hour.used_percentage) { $lim += "5h $([math]::Round($mc.five_hour.used_percentage))%" }
                    if ($null -ne $mc.seven_day.used_percentage) { $lim += "   7d $([math]::Round($mc.seven_day.used_percentage))%" }
                }
                $usF = Join-Path $CacheDir 'copland-usage.json'
                if (Test-Path $usF) {
                    $msc = @((Get-Content $usF -Raw | ConvertFrom-Json).limits |
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
    if ("$k" -match '^[hH]$') {
        # hub als dashboard: links bereiche/projekte, rechts verlauf + offen + skills
        Clear-Host
        $L  = New-Object System.Collections.Generic.List[object]
        $RC = New-Object System.Collections.Generic.List[object]
        $projTotal = 0; $heuteAktiv = 0
        foreach ($ar in $areas) {
            $adir = Join-Path $OD $ar.dir
            # self = bereich ist selbst das projekt (60_assistent)
            $projs = if ($ar.self) { @(Get-Item $adir) }
                     else { @(Get-ChildItem $adir -Directory | Where-Object { $_.Name -notmatch '^[_.]' } | Sort-Object Name) }
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
        foreach ($gl in (git -C $SysDir log --pretty=format:'%ad  %s' --date=format:'%d.%m.' -8)) {
            $gls = "$gl"
            if ($gls.Length -gt 44) { $gls = $gls.Substring(0, 43) + '~' }
            $RC.Add(@{ t = " $gls"; c = "$DIM $gls$R" })
        }
        $RC.Add(@{ t = ''; c = '' })
        $opAll = Get-OffenePunkte
        if ($opAll.Count) {
            $RC.Add(@{ t = 'OFFEN'; c = "${AC}OFFEN$R" })
            $counts = [ordered]@{}
            foreach ($opi in $opAll) { $counts[$opi.sec.ToLower()] = [int]$counts[$opi.sec.ToLower()] + 1 }
            foreach ($sk2 in $counts.Keys) {
                $sn = "$sk2"; if ($sn.Length -gt 34) { $sn = $sn.Substring(0, 33) + '~' }
                $RC.Add(@{ t = " $($sn.PadRight(35))$($counts[$sk2])"; c = "$FG $($sn.PadRight(35))$R$DIM$($counts[$sk2])$R" })
            }
            $RC.Add(@{ t = ''; c = '' })
        }
        $stats = Get-AreaStats
        $balMax = 0
        foreach ($ba in $areas) { if ($stats[$ba.dir].s7 -gt $balMax) { $balMax = $stats[$ba.dir].s7 } }
        if ($balMax -gt 0) {
            $RC.Add(@{ t = 'BALANCE'; c = "${AC}BALANCE$R" })
            foreach ($ba in $areas) {
                $v = $stats[$ba.dir].s7
                $f = [math]::Round($v / $balMax * 10)
                $bt = " $($ba.label.Trim().ToLower().PadRight(9))[$('=' * $f)$('.' * (10 - $f))] $v"
                $RC.Add(@{ t = $bt; c = "$FG $($ba.label.Trim().ToLower().PadRight(9))$R$DIM[$('=' * $f)$('.' * (10 - $f))] $v$R" })
            }
            $RC.Add(@{ t = ''; c = '' })
        }
        $RC.Add(@{ t = 'SKILLS'; c = "${AC}SKILLS$R" })
        $skl = @(Get-ChildItem (Join-Path $ClaudeHome 'skills') -Directory | ForEach-Object { "/$($_.Name)" }) +
               @(Get-ChildItem (Join-Path $ClaudeHome 'commands') -File -Filter *.md | ForEach-Object { "/$($_.BaseName)" })
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
        Write-Host -NoNewline "$DIM  [b] browser   [z] zurueck $R"
        while ($true) {
            $c = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown').Character
            if ("$c" -match '^[bB]$') {
                & (Join-Path $CoplandDir 'copland-hub.ps1') | Out-Null
                Open-Item (Join-Path $CoplandDir 'hub.html')
                break
            }
            if ("$c" -match '^[zZ]$') { break }
        }
        continue
    }
    if ("$k" -match '^[mM]$') {
        Clear-Host
        Get-Content (Join-Path $CoplandDir 'manual.md') | ForEach-Object {
            if ($_ -match '^[A-Z]') { Write-Host "$AC$_$R" } else { Write-Host "$FG$_$R" }
        }
        Wait-Back
        continue
    }
    if ("$k" -match '^[pP]$') {
        # verbindungen: mcp-server, connectoren, cli -- wahrheit in 70_mcp\verbindungen.md
        $mdir = Join-Path $OD '70_mcp'
        $mgen = Join-Path $CoplandDir 'copland-mcp.ps1'
        while ($true) {
            Clear-Host
            Write-Host ""
            Write-Host "$AC   VERBINDUNGEN$R$DIM  mcp, connectoren, cli$R"
            Write-Host "$DIM   ---------------------------------------$R"
            if (Test-Path $mgen) { & $mgen -Text } else { Write-Host "$WARN   copland-mcp.ps1 fehlt$R" }
            Write-Host "$DIM   [b] browser   [e] explorer   [v] verbindungen.md   [z] zurueck$R"
            Write-Host -NoNewline "$AC   > $R"
            $c = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown').Character
            if ("$c" -match '^[zZ]$') { break }
            if ("$c" -match '^[bB]$') { & $mgen; Open-Item (Join-Path $mdir 'mcp.html'); continue }
            if ("$c" -match '^[eE]$') { if ($IsWin) { Start-Process explorer $mdir } else { Open-Item $mdir }; continue }
            if ("$c" -match '^[vV]$') { Open-Item (Join-Path $mdir 'verbindungen.md'); continue }
        }
        continue
    }
    if ("$k" -match '^[67]$') {
        Show-Folder (Join-Path $SysDir 'werkstatt') (Join-Path $SysDir 'werkstatt')
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
            $privat = ($sel.dir -eq '40_private')
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

        # direktstart: ziffer/enter startet SOFORT (modus vorher per praefix r/s/c waehlbar)
        $target = $null
        $mode = 'new'
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
            $modeLbl = switch ($mode) { 'continue' { 'letzte' } 'resume' { 'liste' } 'codex' { 'codex' } default { 'claude neu' } }
            Write-Host "$DIM   [1-9] projekt starten    [enter] ganzer bereich    [n] neues projekt$R"
            Write-Host "$DIM   modus: $R$AC$modeLbl$R$DIM  (aendern: [r] letzte [s] liste [c] codex)    [z] zurueck$R"
            Write-Host -NoNewline "$AC   > $R"
            $pk = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown').Character
            Write-Host ""
            if ("$pk" -match '^[zZ]$') { break }
            if ("$pk" -match '^[rR]$') { $mode = 'continue'; continue }
            if ("$pk" -match '^[sS]$') { $mode = 'resume'; continue }
            if ("$pk" -match '^[cC]$') { $mode = 'codex'; continue }
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
                            "Bereich: $($sel.label.Trim()) | status: aktiv | alias: $pname"
                            "Angelegt: $(Get-Date -Format 'yyyy-MM-dd')."
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
                    $mode = 'new'
                    break
                }
            }
            # jede andere taste: menue neu zeichnen, nichts passiert stillschweigend
        }
        if (-not $target) { continue }
        Start-Claude $target $mode $sel.label.Trim().ToLower()
    }
}
