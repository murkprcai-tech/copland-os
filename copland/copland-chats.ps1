# COPLAND OS -- chats: uebersicht aller claude-code-sessions (wie die chat-liste in der app)
# quelle: ~\.claude\projects\<pfad-mangled>\<id>.jsonl (die session selbst) + ~\.claude\history.jsonl
# (titel = erster prompt, anzahl prompts, letzte zeit -- billig, kein jsonl-parsen).
# liste nach bereich gruppiert, spalten: alter, ernte (ok = der tag wurde von der tagesstart-ernte
# ins brain destilliert, -- = nicht), prompts, mb. ernte-sessions (claude -p) sind ausgeblendet ([e]).
# aktionen: [nr] fortsetzen (claude --resume <id> im projektordner), [d nr] loeschen -> papierkorb
# (%LOCALAPPDATA%\copland-chat-papierkorb, nichts wird endgueltig geloescht) -- vorher optional
# [k] kontext-check: claude -p liest den chat, traegt fehlendes querwissen ins brain ein, meldet kurz.
# [s text] filter, [n]/[p] blaettern, [z] zurueck. aufruf: [c] im launcher oder direkt -File copland-chats.ps1
param()

$ErrorActionPreference = 'SilentlyContinue'
. (Join-Path $PSScriptRoot 'copland-shared.ps1')

$ProjRoot  = Join-Path $ClaudeHome 'projects'
$HistFile  = Join-Path $ClaudeHome 'history.jsonl'
$Papierkorb = Join-Path $CacheDir 'copland-chat-papierkorb'
$PageSize = 18

# bereichs-label aus dem echten projektpfad (10_uni -> UNI ...)
$AreaNames = @{ '10_uni'='uni'; '20_work'='work'; '30_venture'='venture'; '40_private'='private'; '50_career'='career';
                '60_assistent'='alltag'; '80_general'='general'; '00_System'='system'; '70_mcp'='mcp' }
function Get-ProjLabel([string]$p) {
    if (-not $p) { return '?' }
    $rel = $p
    if ($p.ToLower().StartsWith($OD.ToLower())) { $rel = $p.Substring($OD.Length).TrimStart('\', '/') }
    if (-not $rel) { return 'onedrive' }
    $parts = $rel -split '[\\/]'
    $lbl = if ($AreaNames[$parts[0]]) { $AreaNames[$parts[0]] } else { $parts[0] }
    if ($parts.Count -gt 1) { $lbl += ' / ' + ($parts[1..($parts.Count - 1)] -join '/') }
    $lbl
}

# history.jsonl einmal lesen: je session erster prompt, anzahl, letzte zeit, projektpfad
function Get-History {
    $h = @{}
    if (-not (Test-Path $HistFile)) { return $h }
    foreach ($ln in [IO.File]::ReadLines($HistFile)) {
        if (-not $ln) { continue }
        $o = $null; try { $o = $ln | ConvertFrom-Json } catch { continue }
        if (-not $o.sessionId) { continue }
        $id = $o.sessionId
        if (-not $h[$id]) { $h[$id] = @{ title = "$($o.display)"; n = 0; last = 0; project = "$($o.project)" } }
        $h[$id].n++
        if ($o.timestamp -gt $h[$id].last) { $h[$id].last = $o.timestamp }
        if (-not $h[$id].title -and $o.display) { $h[$id].title = "$($o.display)" }
    }
    $h
}

# erster user-prompt direkt aus der jsonl (fallback, wenn history nichts weiss)
function Get-FirstPrompt([string]$file) {
    $i = 0
    foreach ($ln in [IO.File]::ReadLines($file)) {
        if (++$i -gt 80) { break }
        if ($ln -notmatch '"type":"user"') { continue }
        $o = $null; try { $o = $ln | ConvertFrom-Json } catch { continue }
        $c = $o.message.content
        if ($c -is [string]) { return $c }
        if ($c -and $c[0].text) { return "$($c[0].text)" }
    }
    ''
}

# welche tage hat die tagesstart-ernte schon destilliert? (aus copland-ernte.log: 'ernte yyyy-MM-dd: N sessions')
function Get-ErnteTage {
    $t = @{}
    $lg = Join-Path $CacheDir 'copland-ernte.log'
    if (Test-Path $lg) {
        foreach ($ln in [IO.File]::ReadLines($lg)) { if ($ln -match 'ernte (\d{4}-\d{2}-\d{2}): \d+ sessions') { $t[$Matches[1]] = $true } }
    }
    $t
}

# reihenfolge der bereiche in der liste (verfassung: lebensbereiche, dann werkzeuge)
$AreaOrder = @('uni','work','venture','private','career','alltag','general','system','mcp')
function Get-AreaKey([string]$label) {
    $a = ($label -split ' / ')[0]
    $i = [array]::IndexOf($AreaOrder, $a)
    if ($i -lt 0) { $i = 50 }
    '{0:00}' -f $i
}

function Get-Chats {
    $hist = Get-History
    $ernte = Get-ErnteTage
    $list = @()
    foreach ($pd in (Get-ChildItem $ProjRoot -Directory)) {
        foreach ($f in (Get-ChildItem $pd.FullName -File -Filter *.jsonl)) {
            $id = $f.BaseName
            $hi = $hist[$id]
            $title = if ($hi) { $hi.title } else { Get-FirstPrompt $f.FullName }
            $title = ($title -replace '\s+', ' ').Trim()
            if (-not $title) { $title = '(ohne prompt)' }
            $proj = if ($hi -and $hi.project) { $hi.project } else { '' }
            $list += [pscustomobject]@{
                id = $id; file = $f.FullName; dir = $pd.FullName; project = $proj
                label = $(if ($proj) { Get-ProjLabel $proj } else { ($pd.Name.ToLower() -replace ('^' + [regex]::Escape($ODMangled)), '') -replace '^c--users-[a-z0-9]+$', 'home' }); title = $title
                n = $(if ($hi) { $hi.n } else { 0 }); mb = [math]::Round($f.Length / 1MB, 1)
                last = $f.LastWriteTime
                auto = ($title -match '^Tagesstart-Ernte' -or -not $hi)
                geerntet = [bool]$ernte[$f.LastWriteTime.ToString('yyyy-MM-dd')]
            }
        }
    }
    $list | Sort-Object @{e={Get-AreaKey $_.label}}, @{e='last'; Descending=$true}
}

function Fmt-Age([datetime]$t) {
    $m = [int]((Get-Date) - $t).TotalMinutes
    if ($m -lt 60) { "${m}m" } elseif ($m -lt 1440) { "$([int]($m/60))h" } else { "$([int]($m/1440))t" }
}

function Cut([string]$s, [int]$w) { if ($s.Length -gt $w) { $s.Substring(0, $w - 1) + '~' } else { $s.PadRight($w) } }

function Show-List($chats, [int]$page, [string]$filter, [string]$msg, [bool]$showAuto) {
    Clear-Host
    $tot = ($chats | Measure-Object mb -Sum).Sum
    Write-Host ""
    Write-Host "$AC   CHATS$R$DIM   $($chats.Count) sessions | $([math]::Round($tot,0)) mb$(if ($filter) { " | filter: $filter" })$(if ($showAuto) { ' | inkl. ernte-sessions' })$R"
    Write-Host ""
    Write-Host "$DIM   nr   alter  datum   projekt                titel                                         ernte   z    mb$R"
    $start = $page * $PageSize
    $slice = @($chats | Select-Object -Skip $start -First $PageSize)
    $grp = if ($start -gt 0) { ($chats[$start - 1].label -split ' / ')[0] } else { '' }
    for ($i = 0; $i -lt $slice.Count; $i++) {
        $c = $slice[$i]; $nr = $start + $i + 1
        $area = ($c.label -split ' / ')[0]
        if ($area -ne $grp) { $grp = $area; Write-Host "$AC   $area$R" }
        $proj = if ($c.label -like '* / *') { ($c.label -split ' / ', 2)[1] } else { '' }
        $col = if (((Get-Date) - $c.last).TotalDays -lt 2) { $FG } else { $DIM }
        $ern = if ($c.geerntet) { "$DIM ok   " } elseif (((Get-Date).Date - $c.last.Date).Days -lt 1) { "$DIM heute" } else { "$WARN --   " }
        Write-Host ("   $AC" + "$nr".PadLeft(2) + "$R   $col" + (Cut (Fmt-Age $c.last) 6) + " " + $c.last.ToString('dd.MM.') + "  " + (Cut $proj 22) + " " + (Cut $c.title 45) + "$R " + $ern + "$DIM " + "$($c.n)".PadLeft(3) + " " + ("{0,5:0.0}" -f $c.mb) + "$R")
    }
    $pages = [math]::Ceiling($chats.Count / $PageSize)
    Write-Host ""
    if ($pages -gt 1) { Write-Host "$DIM   seite $($page + 1)/$pages$R" }
    if ($msg) { Write-Host "$WARN   $msg$R" }
    Write-Host "$DIM   [nr] fortsetzen   [d nr] loeschen   [s text] filter   [e] ernte-sessions   [n]/[p] seite   [z] zurueck$R"
    Write-Host -NoNewline "$AC   > $R"
}

# transkript einer session als text (nur user/assistant, max $max zeichen) -- wie in der ernte
function Get-Transcript([string]$file, [int]$max = 20000) {
    $sb = New-Object System.Text.StringBuilder
    foreach ($ln in [IO.File]::ReadLines($file)) {
        if ($sb.Length -ge $max) { break }
        if ($ln -notmatch '"type":"(user|assistant)"') { continue }
        $o = $null; try { $o = $ln | ConvertFrom-Json } catch { continue }
        if (-not $o -or -not $o.message) { continue }
        $txt = ''; $c = $o.message.content
        if ($c -is [string]) { $txt = $c } else { foreach ($part in $c) { if ($part.type -eq 'text' -and $part.text) { $txt += $part.text + ' ' } } }
        $txt = ($txt -replace '\s+', ' ').Trim()
        if (-not $txt -or $txt -match '^<(local-command|command-|system-reminder)') { continue }
        if ($txt.Length -gt 600) { $txt = $txt.Substring(0, 600) + '~' }
        [void]$sb.AppendLine("$($o.type): $txt")
    }
    $sb.ToString()
}

# kontext-check vor dem loeschen: claude -p liest den chat, vergleicht mit brain, traegt fehlendes ein
function Invoke-KontextCheck($c) {
    $inp = Join-Path $CacheDir 'copland-chat-check.txt'
    (Get-Transcript $c.file) | Set-Content $inp -Encoding utf8
    $brain = Join-Path $OD '60_assistent/brain'
    $prompt = @"
Kontext-Check vor dem Loeschen eines Chats ($($c.label), $($c.last.ToString('yyyy-MM-dd'))). Du bist Markos Personal Assistant (60_assistent).
Lies $inp (gekuerztes Transkript). Pruefe, ob darin projektuebergreifendes Querwissen steckt, das NOCH NICHT im Brain steht
(Dateien in ${brain}: personen.md, entscheidungen.md, vorlieben.md, laufend.md; Fristen: $(Join-Path $OD '60_assistent/erinnerungen.md')).
Vorher lesen, deduplizieren, nur Fehlendes eintragen (eine datierte Zeile je Fakt, Format im Kopf jeder Datei). Nichts erfinden,
nichts Projektinternes, keine anderen Dateien anfassen. Antworte mit maximal 4 Zeilen: was eingetragen wurde -- oder 'nichts neues'.
"@
    Write-Host "$DIM   kontext-check laeuft (claude -p) ...$R"
    $out = & claude -p $prompt --model sonnet --permission-mode bypassPermissions --add-dir $OD --add-dir $CacheDir 2>&1
    Write-Host ""
    foreach ($l in ("$out" -split "`n")) { if ($l.Trim()) { Write-Host "$FG   $($l.Trim())$R" } }
    Write-Host ""
}

# session in den papierkorb: jsonl + sidecar-ordner (gleicher name) -> %LOCALAPPDATA%\copland-chat-papierkorb\<projdir>\
function Move-ToPapierkorb($c) {
    $dest = Join-Path $Papierkorb (Split-Path $c.dir -Leaf)
    New-Item -ItemType Directory -Force -Path $dest | Out-Null
    Move-Item $c.file $dest -Force
    $side = Join-Path $c.dir $c.id
    if (Test-Path $side) { Move-Item $side $dest -Force }
}

$all = Get-Chats
$page = 0; $filter = ''; $msg = ''; $showAuto = $false
while ($true) {
    $view = @($all | Where-Object { $showAuto -or -not $_.auto })
    if ($filter) { $view = @($view | Where-Object { ($_.title + ' ' + $_.label) -match [regex]::Escape($filter) }) }
    Show-List $view $page $filter $msg $showAuto
    $msg = ''
    $in = [Console]::ReadLine()
    if ($null -eq $in) { break }
    $in = $in.Trim()
    if ($in -match '^[zZ]$') { break }
    if ($in -match '^[eE]$') { $showAuto = -not $showAuto; $page = 0; continue }
    if ($in -match '^[nN]$') { if (($page + 1) * $PageSize -lt $view.Count) { $page++ }; continue }
    if ($in -match '^[pP]$') { if ($page -gt 0) { $page-- }; continue }
    if ($in -match '^[sS]\s*(.*)$') { $filter = $Matches[1].Trim(); $page = 0; continue }
    if ($in -match '^[dD]\s*(\d+)$') {
        $nr = [int]$Matches[1]
        if ($nr -lt 1 -or $nr -gt $view.Count) { $msg = "nr $nr gibt es nicht"; continue }
        $c = $view[$nr - 1]
        Write-Host ""
        Write-Host "$WARN   loeschen: $($c.label) -- $(Cut $c.title 50)$R"
        Write-Host "$DIM   ernte: $(if ($c.geerntet) { 'tag wurde destilliert (brain hat das querwissen)' } elseif ($c.auto) { 'automatische session, kein eigener inhalt' } else { 'NICHT destilliert -- querwissen koennte fehlen' })$R"
        Write-Host -NoNewline "$DIM   [j] papierkorb   [k] erst kontext-check (claude -p), dann papierkorb   [n] abbrechen $R"
        $ok = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown').Character
        Write-Host $ok
        if ("$ok" -match '^[kK]$') {
            if (-not (Get-Command claude -ErrorAction SilentlyContinue)) { $msg = 'claude nicht gefunden'; continue }
            Invoke-KontextCheck $c
            Write-Host -NoNewline "$DIM   jetzt in den papierkorb? [j/n] $R"
            $ok = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown').Character
            Write-Host $ok
        }
        if ("$ok" -match '^[jJyY]$') {
            Move-ToPapierkorb $c
            $all = @($all | Where-Object { $_.id -ne $c.id })
            Get-CoplandIndex -Force | Out-Null
            $msg = "verschoben -> $Papierkorb"
        }
        continue
    }
    if ($in -match '^\d+$') {
        $nr = [int]$in
        if ($nr -lt 1 -or $nr -gt $view.Count) { $msg = "nr $nr gibt es nicht"; continue }
        $c = $view[$nr - 1]
        $dir = if ($c.project -and (Test-Path $c.project)) { $c.project } else { $OD }
        if (-not (Get-Command claude -ErrorAction SilentlyContinue)) { $msg = 'claude nicht gefunden'; continue }
        Set-Location $dir
        $Host.UI.RawUI.WindowTitle = $c.label
        Clear-Host
        Write-Host ""
        Write-Host "$DIM  copland: verbinde -> $($c.label)  ($(Cut $c.title 40))$R"
        Write-Host ""
        claude --resume $c.id
        $all = Get-Chats
        continue
    }
    if ($in) { $msg = "unbekannt: $in" }
}
