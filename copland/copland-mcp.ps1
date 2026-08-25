# COPLAND OS -- Verbindungen-Generator
# baut 70_mcp\mcp.html aus 70_mcp\verbindungen.md (die wahrheit) + `claude mcp list`
# (live-status der registrierten server) + ~\.claude.json / settings.json (mcpServers).
# aufruf: [p] -> [b] im launcher, oder nach jedem `claude mcp add/remove`.
# parameter -Text: statt html die tabelle kompakt ins terminal schreiben (launcher [p]).

param([switch]$Text)

$ErrorActionPreference = 'SilentlyContinue'
. (Join-Path $PSScriptRoot 'copland-shared.ps1')
$McpDir = Join-Path $OD '70_mcp'
$src    = Join-Path $McpDir 'verbindungen.md'
$out    = Join-Path $McpDir 'mcp.html'

# --- tabelle aus verbindungen.md ---
$rows = @()
if (Test-Path $src) {
    foreach ($ln in (Get-Content $src -Encoding utf8)) {
        if ($ln -notmatch '^\|') { continue }
        $cells = @(($ln.Trim().Trim('|') -split '\|') | ForEach-Object { $_.Trim() })
        if ($cells.Count -lt 6) { continue }
        if ($cells[0] -eq 'name' -or $cells[0] -match '^-+$') { continue }
        $rows += @{ name = $cells[0]; art = $cells[1]; zweck = $cells[2]; status = $cells[3].ToLower(); geprueft = $cells[4]; notiz = $cells[5] }
    }
}

# --- live: claude mcp list (nur wenn claude da ist, max ~10s) ---
$live = @{}
if (Get-Command claude -ErrorAction SilentlyContinue) {
    $lst = & claude mcp list 2>&1
    foreach ($ll in $lst) {
        if ("$ll" -match '^(?:claude\.ai\s+)?(.+?):\s+(.+?)\s+-\s+(.+)$') {
            $nm = $Matches[1].Trim(); $st = $Matches[3].Trim()
            $live[$nm.ToLower()] = if ($st -match 'Connected') { 'connected' } elseif ($st -match 'auth') { 'auth' } else { 'failed' }
        }
    }
}
# live-status ueberschreibt die tabelle, wo er etwas weiss
foreach ($rw in $rows) {
    $lk = $rw.name.ToLower()
    if ($live.ContainsKey($lk)) {
        $rw.live = $live[$lk]
        if ($live[$lk] -eq 'auth')      { $rw.status = 'anmeldung noetig' }
        if ($live[$lk] -eq 'connected' -and $rw.status -in @('ungetestet', 'aus')) { $rw.status = 'laeuft' }
        if ($live[$lk] -eq 'failed')    { $rw.status = 'aus' }
    }
}
# registrierte server, die in der tabelle fehlen -> anhaengen
foreach ($lk in $live.Keys) {
    if (-not ($rows | Where-Object { $_.name.ToLower() -eq $lk })) {
        $rows += @{ name = $lk; art = 'mcp (nicht in tabelle)'; zweck = '?'; status = $(if ($live[$lk] -eq 'connected') { 'laeuft' } elseif ($live[$lk] -eq 'auth') { 'anmeldung noetig' } else { 'aus' }); geprueft = (Get-Date).ToString('yyyy-MM-dd'); notiz = 'in verbindungen.md eintragen'; live = $live[$lk] }
    }
}

# --- was tun ---
function Get-Todo($rw) {
    switch ($rw.status) {
        'anmeldung noetig' { if ($rw.art -match 'connector') { 'claude.ai -> settings -> connectors -> verbinden' } else { 'einmal authentifizieren (siehe notiz)' } }
        'ungetestet'       { 'einmal benutzen, dann status setzen' }
        'aus'              { 'registrieren oder entfernen (siehe notiz)' }
        'geplant'          { 'noch nicht gebaut' }
        default            { '' }
    }
}

$nOk   = @($rows | Where-Object { $_.status -eq 'laeuft' }).Count
$nAuth = @($rows | Where-Object { $_.status -eq 'anmeldung noetig' }).Count
$nOff  = @($rows | Where-Object { $_.status -in @('aus', 'ungetestet') }).Count
$nPlan = @($rows | Where-Object { $_.status -eq 'geplant' }).Count
$stamp = (Get-Date).ToString('yyyy-MM-dd HH:mm')

# --- terminal-ausgabe fuer den launcher ---
if ($Text) {
    Write-Host "$DIM   $nOk laufen   $nAuth anmeldung   $nOff aus/ungetestet   $nPlan geplant$R"
    Write-Host ""
    foreach ($grp in @('claude.ai connector', 'mcp lokal', 'cli', 'bruecke')) {
        $g = @($rows | Where-Object { $_.art -like "$grp*" })
        if (-not $g) { continue }
        Write-Host "$AC   $grp$R"
        foreach ($rw in $g) {
            $col = switch ($rw.status) { 'laeuft' { $FG } 'anmeldung noetig' { $WARN } 'geplant' { $DIM } default { $DIM } }
            $dot = switch ($rw.status) { 'laeuft' { '*' } 'anmeldung noetig' { '!' } 'geplant' { '.' } default { '-' } }
            $z = $rw.zweck; if ($z.Length -gt 40) { $z = $z.Substring(0, 39) + '~' }
            Write-Host "$col   $dot $($rw.name.PadRight(20))$R$DIM $($rw.status.PadRight(17)) $z$R"
        }
        Write-Host ""
    }
    $rest = @($rows | Where-Object { $_.art -notmatch '^(claude\.ai connector|mcp lokal|cli|bruecke)' })
    foreach ($rw in $rest) { Write-Host "$WARN   ? $($rw.name.PadRight(20))$R$DIM $($rw.status) -- $($rw.notiz)$R" }
    return
}

# --- html ---
function Esc([string]$s) { [System.Net.WebUtility]::HtmlEncode($s) }
$B = New-Object System.Text.StringBuilder
foreach ($grp in @(@('claude.ai connector', 'claude.ai connectoren'), @('mcp lokal', 'mcp-server lokal'), @('cli', 'cli-werkzeuge'), @('bruecke', 'bruecken'), @('mcp (nicht in tabelle)', 'registriert, aber nicht in der tabelle'))) {
    $g = @($rows | Where-Object { $_.art -like "$($grp[0])*" })
    if (-not $g) { continue }
    [void]$B.AppendLine("<div class=`"sep`">.... $(Esc $grp[1]) ....</div><div class=`"grid`">")
    foreach ($rw in $g) {
        $cls = switch ($rw.status) { 'laeuft' { 'ok' } 'anmeldung noetig' { 'auth' } 'geplant' { 'plan' } default { 'off' } }
        $todo = Get-Todo $rw
        [void]$B.AppendLine("<div class=`"card $cls`"><span class=`"meta`">$(Esc $rw.geprueft)</span><b><span class=`"dot`"></span>$(Esc $rw.name)</b>")
        [void]$B.AppendLine("<p class=`"dim`">$(Esc $rw.art) &middot; <span class=`"st`">$(Esc $rw.status)</span></p>")
        [void]$B.AppendLine("<p>$(Esc $rw.zweck)</p>")
        if ($todo) { [void]$B.AppendLine("<p class=`"todo`">&gt; $(Esc $todo)</p>") }
        if ($rw.notiz) { [void]$B.AppendLine("<p class=`"dim note`">$(Esc $rw.notiz)</p>") }
        [void]$B.AppendLine("</div>")
    }
    [void]$B.AppendLine("</div>")
}

$html = @"
<!doctype html><html lang="de"><head><meta charset="utf-8">
<title>copland verbindungen</title>
<style>
  :root { --fg:#B8C4CE; --ac:#8CABC6; --dim:#4A5866; --warn:#C2848F; --line:#1C2731; }
  body { background:#000; color:var(--fg); font-family:"Departure Mono","Consolas",monospace;
         font-size:13px; line-height:1.5; margin:0; padding:26px 34px; }
  h1 { color:var(--ac); font-size:15px; font-weight:normal; margin:0; }
  .dim { color:var(--dim); } .warn { color:var(--warn); }
  .sep { color:var(--dim); margin:20px 0 10px; letter-spacing:2px; }
  .sum { margin-top:6px; color:var(--dim); }
  .sum b { color:var(--fg); font-weight:normal; } .sum .w { color:var(--warn); }
  .grid { display:grid; grid-template-columns:repeat(auto-fill,minmax(330px,1fr)); gap:10px; }
  .card { border:1px solid var(--line); padding:10px 12px; }
  .card b { color:var(--ac); font-weight:normal; }
  .card .meta { color:var(--dim); float:right; }
  .card p { margin:4px 0 0; }
  .card .note { font-size:12px; }
  .dot { display:inline-block; width:7px; height:7px; margin-right:8px; background:var(--dim); vertical-align:middle; }
  .ok .dot { background:var(--ac); } .auth .dot { background:var(--warn); } .off .dot { background:var(--dim); } .plan .dot { background:#000; border:1px solid var(--dim); box-sizing:border-box; }
  .auth .st, .auth .todo { color:var(--warn); } .ok .st { color:var(--ac); } .off .st, .plan .st { color:var(--dim); } .todo { color:var(--dim); }
  .foot { margin-top:22px; color:var(--dim); }
</style></head><body>
<h1>COPLAND OS -- VERBINDUNGEN</h1>
<div class="sum">$stamp &middot; <b>$nOk</b> laufen &middot; <span class="w">$nAuth</span> anmeldung noetig &middot; $nOff aus/ungetestet &middot; $nPlan geplant</div>
$($B.ToString())
<div class="foot">quelle: 70_mcp\verbindungen.md + claude mcp list &middot; generator: 00_System\copland\copland-mcp.ps1 &middot; launcher [p]</div>
</body></html>
"@
Set-Content $out $html -Encoding utf8
