# COPLAND OS -- Statusline fuer Claude Code (pure ASCII)
# eine zeile: [wired] BEREICH | ordner
# alle details (modell, effort, ctx, limits) gehen per cache ans panel

$ErrorActionPreference = 'SilentlyContinue'
$raw = [Console]::In.ReadToEnd()
$j = $raw | ConvertFrom-Json

# Farben (kaltes Blaugrau)
$E    = [char]27
$FG   = "$E[38;2;184;196;206m"
$AC   = "$E[38;2;140;171;198m"
$DIM  = "$E[38;2;74;88;102m"
$R    = "$E[0m"
$SEP  = " ${DIM}|${R} "

# --- Bereich aus Pfad ableiten ---
$dir = $j.workspace.current_dir
$name = Split-Path $dir -Leaf
$area = switch -Wildcard ($dir) {
    '*10_uni*'       { 'UNI' }
    '*20_work*'      { 'WORK' }
    '*30_venture*'   { 'VENTURE' }
    '*40_private*'   { 'PRIVATE' }
    '*50_career*'    { 'CAREER' }
    '*00_System*'    { 'SYSTEM' }
    '*90_Archiv*'    { 'ARCHIV' }
    '*seadrive*'     { 'SEAFILE' }
    default          { '--' }
}

# --- Daten fuers Panel sammeln ---
$model = $j.model.display_name
if (-not $model) { $model = $j.model.id }
$model = "$model".ToLower()
$ctx = $null
if ($null -ne $j.context_window.used_percentage) { $ctx = [math]::Round($j.context_window.used_percentage) }

if (-not $env:USERPROFILE) { $env:USERPROFILE = $HOME }
$od = if ($env:COPLAND_ROOT) { $env:COPLAND_ROOT } else { Join-Path $env:USERPROFILE 'OneDrive' }
$rel = $dir
if ($dir -like "$od*") { $rel = $dir.Substring($od.Length).TrimStart('\') }
if (-not $rel) { $rel = 'OneDrive' }

@{
    model     = $model
    effort    = $j.effort.level
    ctx       = $ctx
    area      = $area
    dir       = $rel
    five_hour = $j.rate_limits.five_hour
    seven_day = $j.rate_limits.seven_day
    ccv       = $j.version
    ts        = [DateTimeOffset]::Now.ToUnixTimeSeconds()
} | ConvertTo-Json -Compress | Set-Content "$env:LOCALAPPDATA\copland-limits.json" -Encoding utf8

# --- Git-Sync-Status fuers Panel (Anzeige rechts, nicht hier unten) ---
# behind = Commits auf origin, die lokal fehlen -> /nachziehen
# ahead  = lokale Commits, die noch nicht gepusht sind -> /abgeben
$git = $null
$gitDir = git -C $dir rev-parse --absolute-git-dir 2>$null
if ($gitDir) {
    # Remote-Stand per Hintergrund-Fetch, gedrosselt auf ~120 s (Marker-Datei).
    # Fetch blockiert nie das Rendern und fragt nie nach Credentials.
    $marker = Join-Path $gitDir 'copland-fetch-ts'
    $now = [DateTimeOffset]::Now.ToUnixTimeSeconds()
    $last = 0
    if (Test-Path $marker) { $last = [int64](Get-Content $marker -Raw).Trim() }
    if ($now - $last -ge 120) {
        Set-Content $marker $now -Encoding ascii
        Start-Process -WindowStyle Hidden powershell.exe -ArgumentList `
            '-NoProfile', '-Command', "`$env:GIT_TERMINAL_PROMPT='0'; git -C '$dir' fetch --quiet" | Out-Null
    }
    # ahead/behind + Konflikt-Zustand rein lokal ermitteln (billig, kein Netz).
    $behind = 0; $ahead = 0
    $counts = git -C $dir rev-list --left-right --count '@{u}...HEAD' 2>$null
    if ($counts -match '^(\d+)\s+(\d+)') { $behind = [int]$Matches[1]; $ahead = [int]$Matches[2] }
    $conflict = (Test-Path (Join-Path $gitDir 'MERGE_HEAD')) -or
                (Test-Path (Join-Path $gitDir 'rebase-merge')) -or
                (Test-Path (Join-Path $gitDir 'rebase-apply'))
    $git = @{ behind = $behind; ahead = $ahead; conflict = [bool]$conflict }
}

# --- Session-Datei fuer die Panel-Uebersicht (aktive sessions) ---
$sdir = "$env:LOCALAPPDATA\copland-sessions"
if (-not (Test-Path $sdir)) { New-Item -ItemType Directory -Path $sdir -Force | Out-Null }
if ($j.session_id) {
    @{ area = $area; name = $name; git = $git; ts = [DateTimeOffset]::Now.ToUnixTimeSeconds() } |
        ConvertTo-Json -Compress | Set-Content "$sdir\$($j.session_id).json" -Encoding utf8
}
Get-ChildItem $sdir -File | Where-Object { $_.LastWriteTime -lt (Get-Date).AddMinutes(-10) } | Remove-Item -Force

# --- Ausgabe (eine zeile) ---
Write-Output "${DIM}[wired]${R} ${AC}${area}${R}${SEP}${FG}${name}${R}"
