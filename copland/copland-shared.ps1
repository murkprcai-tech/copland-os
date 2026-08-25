# COPLAND OS -- gemeinsame konstanten (farben)
#
# ACHTUNG: ps-variablen sind case-insensitiv. die namen E, FG, AC, DIM, WARN, R
# sind hiermit reserviert -- NIE als laufvariablen o.ae. verwenden ($r zerstoert $R,
# das gab schon dreimal kaputte anzeigen: wetter, hub-rendering, hauptmenue).
# wird von copland.ps1 und copland-panel.ps1 dot-sourced.
# ausnahme: die statuslines in ~/.claude tragen eine eigene kopie,
# damit sie auch ohne onedrive-zugriff funktionieren.

$E    = [char]27
$FG   = "$E[38;2;184;196;206m"   # grundton
$AC   = "$E[38;2;140;171;198m"   # akzent
$DIM  = "$E[38;2;74;88;102m"     # gedimmt
$WARN = "$E[38;2;194;132;143m"   # warnung
$R    = "$E[0m"

# --- plattform ---------------------------------------------------------------
# laeuft 1:1 auf windows (powershell 5.1 / pwsh 7) und macos/linux (pwsh 7).
# die skripte erkennen das system selbst -- nichts zu konfigurieren ausser
# COPLAND_ROOT = ordner mit den bereichen (00_System, 10_uni, ...), default ~/OneDrive.
# regel: pfade IMMER mit Join-Path oder '/' bauen -- windows versteht beides,
# unix nur '/'. fehlende windows-variablen werden fuer unix nachgebildet.
$IsWin = ($env:OS -eq 'Windows_NT')
$IsMac = [bool](Get-Variable IsMacOS -ValueOnly -ErrorAction SilentlyContinue)
$IsLin = (-not $IsWin) -and (-not $IsMac)
if (-not $env:HOME)        { $env:HOME = $env:USERPROFILE }
if (-not $env:USERPROFILE) { $env:USERPROFILE = $HOME }
if (-not $env:LOCALAPPDATA) {
    $env:LOCALAPPDATA = Join-Path $HOME '.cache/copland'
    $null = New-Item -ItemType Directory -Force -Path $env:LOCALAPPDATA
}
if (-not $env:TEMP) { $env:TEMP = [IO.Path]::GetTempPath().TrimEnd('/', '\') }
$OD    = if ($env:COPLAND_ROOT) { $env:COPLAND_ROOT } else { Join-Path $env:USERPROFILE 'OneDrive' }
$OD    = $OD.TrimEnd('/', '\')
$PSExe = if ($IsWin) { 'powershell' } else { 'pwsh' }
# feste orte (eine stelle, ueberall dieselben namen)
$SysDir     = Join-Path $OD '00_System'           # systemraum (STATE.md, offene-punkte.md, werkstatt)
$CoplandDir = $PSScriptRoot                       # dieser ordner (launcher, panel, hub, manual)
$ClaudeHome = Join-Path $env:USERPROFILE '.claude'
$CacheDir   = $env:LOCALAPPDATA                   # panel-caches (limits, usage, index, sessions)
# claude code benennt session-ordner nach dem pfad (nicht-alphanumerisch -> '-'), z.b. c--users-me-onedrive-10-uni
$ODMangled = (($OD -replace '[^A-Za-z0-9]', '-') + '-').ToLower()
function ConvertTo-SessionName([string]$p) { ($p -replace '[^A-Za-z0-9]', '-').ToLower() }
# datei/url mit dem systemstandard oeffnen (explorer / open / xdg-open)
function Open-Item([string]$p) {
    if ($IsWin) { Start-Process $p }
    elseif (Get-Command open -ErrorAction SilentlyContinue) { & open $p }
    else { & xdg-open $p }
}
# skript unsichtbar im hintergrund starten (state-generator u.ae.)
function Start-Hidden([string]$scriptPath) {
    if ($IsWin) { Start-Process -WindowStyle Hidden $PSExe -ArgumentList '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $scriptPath }
    else        { Start-Process $PSExe -ArgumentList '-NoProfile', '-File', $scriptPath }
}
# umgebungsvariable: windows = user-scope (setx), unix = prozess/profil
function Get-UserEnv([string]$n) {
    $v = $null
    if ($IsWin) { $v = [Environment]::GetEnvironmentVariable($n, 'User') }
    if (-not $v) { $v = [Environment]::GetEnvironmentVariable($n) }
    $v
}
# claude-oauth-token: datei (windows/linux) oder keychain (macos)
function Get-ClaudeToken {
    $f = Join-Path $ClaudeHome '.credentials.json'
    if (Test-Path $f) { try { return (Get-Content $f -Raw | ConvertFrom-Json).claudeAiOauth.accessToken } catch { } }
    if ($IsMac) {
        try {
            $raw = & security find-generic-password -s 'Claude Code-credentials' -w 2>$null
            if ($raw) { return ("$raw" | ConvertFrom-Json).claudeAiOauth.accessToken }
        } catch { }
    }
    $null
}

# ascii-balken: anteil $p (0-100) auf breite $w
function Bar([double]$p, [int]$w) {
    $f = [math]::Round($p / 100 * $w)
    if ($f -gt $w) { $f = $w }
    if ($f -lt 0)  { $f = 0 }
    ('=' * $f) + ('.' * ($w - $f))
}

# aktivitaets-level 0-4 aus sessions/tag (EINE stelle fuer die schwellen)
function Get-ActivityLevel([int]$v) {
    if ($v -ge 7) { 4 } elseif ($v -ge 4) { 3 } elseif ($v -ge 2) { 2 } elseif ($v -ge 1) { 1 } else { 0 }
}

# offene-punkte.md parsen: liste aus @{sec; text}
function Get-OffenePunkte {
    $op = Join-Path $SysDir 'offene-punkte.md'
    $out = @()
    if (Test-Path $op) {
        $sec = ''
        foreach ($opl in (Get-Content $op -Encoding utf8)) {
            if ($opl -match '^##\s+(.*)') { $sec = $Matches[1] }
            elseif ($sec -and $opl -match '^\s*-\s*(.+)') { $out += @{ sec = $sec; text = $Matches[1] } }
        }
    }
    , $out
}

# projekt-CLAUDE.md-kopfzeile + zweck/stand parsen (EIN parser fuer alle)
function Get-ProjectMeta([string]$projPath) {
    $meta = @{ alias = ''; status = ''; verbunden = @(); frist = ''; zweck = ''; stand = ''; hasCmd = $false }
    $cmd = Join-Path $projPath 'CLAUDE.md'
    if (-not (Test-Path $cmd)) { return $meta }
    $meta.hasCmd = $true
    $sec = ''
    foreach ($ml in (Get-Content $cmd -Encoding utf8)) {
        if ($ml -match '^##\s+(\S+)') { $sec = $Matches[1].ToLower(); continue }
        if ($ml -match 'alias:\s*([^|]+)') { $meta.alias = $Matches[1].Trim() -replace '\s*,\s*', ',' }
        if ($ml -match 'status:\s*(\w+)') { $meta.status = $Matches[1].ToLower() }
        if ($ml -match '^Verbunden:\s*(.+)') { foreach ($ka in ($Matches[1] -split ';')) { $meta.verbunden += $ka.Trim() } }
        if ($ml -match '^Frist:\s*(\d{4}-\d{2}-\d{2})\s*(.*)') { $meta.frist = "$($Matches[1]) $($Matches[2])" }
        if ($sec -eq 'zweck' -and -not $meta.zweck -and $ml.Trim() -and $ml -notmatch '^#') { $meta.zweck = $ml.Trim() }
        if ($sec -eq 'stand' -and $ml -match '^\s*-\s*(.+)') { $meta.stand = $Matches[1] }
    }
    $meta
}

# session-index: EIN scan ueber ~\.claude\projects, gecacht als json (10 min).
# liefert je session-ordner (kleingeschrieben): newest (iso), s7, s30 -- plus heat (datum->anzahl, 112d)
function Get-CoplandIndex([switch]$Force) {
    $idxFile = Join-Path $CacheDir 'copland-index.json'
    if (-not $Force -and (Test-Path $idxFile)) {
        if (((Get-Date) - (Get-Item $idxFile).LastWriteTime).TotalMinutes -lt 10) {
            return (Get-Content $idxFile -Raw | ConvertFrom-Json)
        }
    }
    $sess = @{}
    $heat = @{}
    Get-ChildItem (Join-Path $ClaudeHome 'projects') -Directory | ForEach-Object {
        $files = @(Get-ChildItem $_.FullName -File -Filter *.jsonl)
        if (-not $files) { return }
        $newest = ($files | Sort-Object LastWriteTime -Descending)[0].LastWriteTime
        $s7 = 0; $s30 = 0
        foreach ($sf in $files) {
            $aged = ((Get-Date) - $sf.LastWriteTime).TotalDays
            if ($aged -le 112) { $dk = $sf.LastWriteTime.Date.ToString('yyyy-MM-dd'); $heat[$dk] = [int]$heat[$dk] + 1 }
            if ($aged -le 7) { $s7++ }
            if ($aged -le 30) { $s30++ }
        }
        $sess[$_.Name.ToLower()] = @{ newest = $newest.ToString('o'); s7 = $s7; s30 = $s30 }
    }
    $idx = @{ generated = (Get-Date).ToString('o'); sessions = $sess; heat = $heat }
    $idx | ConvertTo-Json -Depth 5 -Compress | Set-Content $idxFile -Encoding utf8
    Get-Content $idxFile -Raw | ConvertFrom-Json
}

# braille-charts: 2x4 punkte pro zelle = 8x aufloesung. auf $false stellen,
# falls die glyphen im font haesslich rendern -> alles faellt auf ascii zurueck.
$UseBraille = $true

# liniendiagramm als braille-zeilen. $vals -> $cellsW x $cellsH zellen,
# $maxV = feste skala (0 = auto). gibt $null zurueck, wenn braille aus ist.
function ConvertTo-BrailleChart([double[]]$vals, [int]$cellsW, [int]$cellsH, [double]$maxV = 0) {
    if (-not $script:UseBraille) { return $null }
    if (-not $vals -or $vals.Count -lt 2) { return $null }
    $pw = $cellsW * 2; $ph = $cellsH * 4
    if ($maxV -le 0) { $maxV = ($vals | Measure-Object -Maximum).Maximum }
    if ($maxV -le 0) { $maxV = 1 }
    $grid = New-Object 'bool[,]' $ph, $pw
    $prevY = -1
    for ($x = 0; $x -lt $pw; $x++) {
        $t = $x / [double]($pw - 1) * ($vals.Count - 1)
        $i0 = [int][math]::Floor($t); $i1 = [math]::Min($vals.Count - 1, $i0 + 1)
        $v = $vals[$i0] + ($vals[$i1] - $vals[$i0]) * ($t - $i0)
        $y = [int][math]::Round(($ph - 1) * (1 - [math]::Min(1.0, $v / $maxV)))
        if ($prevY -ge 0) {
            $lo = [math]::Min($prevY, $y); $hi = [math]::Max($prevY, $y)
            for ($yy = $lo; $yy -le $hi; $yy++) { $grid[$yy, $x] = $true }
        } else { $grid[$y, $x] = $true }
        $prevY = $y
    }
    $bits = @(@(0x01, 0x02, 0x04, 0x40), @(0x08, 0x10, 0x20, 0x80))
    $lines = @()
    for ($cy = 0; $cy -lt $cellsH; $cy++) {
        $ln = ''
        for ($cx = 0; $cx -lt $cellsW; $cx++) {
            $code = 0x2800
            for ($sx = 0; $sx -lt 2; $sx++) {
                for ($sy = 0; $sy -lt 4; $sy++) {
                    if ($grid[($cy * 4 + $sy), ($cx * 2 + $sx)]) { $code = $code -bor $bits[$sx][$sy] }
                }
            }
            $ln += [char]$code
        }
        $lines += $ln
    }
    , $lines
}

# --- spotify ueber die system-media-session (windows WinRT / macos osascript) ----------------
# kein api-key, keine anmeldung: liest und steuert die laufende spotify-desktop-app.
# Get-SpotifyNow  -> @{title;artist;album;playing;pos;len} oder $null
# Invoke-SpotifyCtl 'toggle'|'next'|'prev'|'play'|'pause'
$script:SpMediaInit = $false
$script:SpAsTaskG = $null
function Get-SpotifySession {
    if (-not $IsWin) { return $null }
    try {
        if (-not $script:SpMediaInit) {
            $script:SpMediaInit = $true
            Add-Type -AssemblyName System.Runtime.WindowsRuntime -ErrorAction Stop
            $null = [Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager, Windows.Media.Control, ContentType = WindowsRuntime]
            $script:SpAsTaskG = ([System.WindowsRuntimeSystemExtensions].GetMethods() |
                Where-Object { $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq ('IAsyncOperation' + [char]96 + '1') })[0]
        }
        if (-not $script:SpAsTaskG) { return $null }
        $tk = $script:SpAsTaskG.MakeGenericMethod([Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager]).Invoke(
            $null, @([Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager]::RequestAsync()))
        if (-not $tk.Wait(2000)) { return $null }
        @($tk.Result.GetSessions()) | Where-Object { $_.SourceAppUserModelId -match 'Spotify' } | Select-Object -First 1
    } catch { $null }
}
function Get-SpotifyNow {
    if ($IsWin) {
        try {
            $ses = Get-SpotifySession
            if (-not $ses) { return $null }
            $tkP = $script:SpAsTaskG.MakeGenericMethod([Windows.Media.Control.GlobalSystemMediaTransportControlsSessionMediaProperties]).Invoke(
                $null, @($ses.TryGetMediaPropertiesAsync()))
            if (-not $tkP.Wait(2000)) { return $null }
            $mp = $tkP.Result
            $tl = $ses.GetTimelineProperties(); $pi = $ses.GetPlaybackInfo()
            return @{ title = "$($mp.Title)"; artist = "$($mp.Artist)"; album = "$($mp.AlbumTitle)"
                      playing = ("$($pi.PlaybackStatus)" -eq 'Playing')
                      pos = [int]$tl.Position.TotalSeconds; len = [int]$tl.EndTime.TotalSeconds }
        } catch { return $null }
    } elseif ($IsMac) {
        try {
            $osa = 'tell application "System Events" to set ok to (name of processes) contains "Spotify"' + "`n" +
                   'if not ok then return ""' + "`n" +
                   'tell application "Spotify" to return (player state as string) & "|" & (name of current track) & "|" & (artist of current track) & "|" & (album of current track) & "|" & player position & "|" & ((duration of current track) / 1000)'
            $out = & osascript -e $osa 2>$null
            if (-not "$out") { return $null }
            $pp = "$out" -split '\|'
            if ($pp.Count -lt 6) { return $null }
            return @{ title = $pp[1]; artist = $pp[2]; album = $pp[3]; playing = ($pp[0] -eq 'playing')
                      pos = [int][double]$pp[4]; len = [int][double]$pp[5] }
        } catch { return $null }
    }
    $null
}
function Invoke-SpotifyCtl([string]$cmd) {
    if ($IsWin) {
        $ses = Get-SpotifySession
        if (-not $ses) { return $false }
        try {
            switch ($cmd) {
                'toggle' { $null = $ses.TryTogglePlayPauseAsync() }
                'next'   { $null = $ses.TrySkipNextAsync() }
                'prev'   { $null = $ses.TrySkipPreviousAsync() }
                'play'   { $null = $ses.TryPlayAsync() }
                'pause'  { $null = $ses.TryPauseAsync() }
            }
            return $true
        } catch { return $false }
    } elseif ($IsMac) {
        $map = @{ toggle = 'playpause'; next = 'next track'; prev = 'previous track'; play = 'play'; pause = 'pause' }
        if (-not $map[$cmd]) { return $false }
        try { & osascript -e "tell application `"Spotify`" to $($map[$cmd])" 2>$null; return $true } catch { return $false }
    }
    $false
}
