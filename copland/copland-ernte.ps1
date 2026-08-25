# COPLAND OS -- Tagesstart-Ernte
# destilliert die sessions von GESTERN ins brain (60_assistent/brain), ergaenzt erinnerungen,
# baut STATE neu. ereignisgesteuert: der launcher startet das 1x pro tag versteckt
# (marker %LOCALAPPDATA%\copland-tagesstart-yyyy-MM-dd), weil der laptop nur an ist,
# wenn der nutzer arbeitet. manuell: -Force (ignoriert marker), -Tag yyyy-MM-dd (anderer tag).
# log: %LOCALAPPDATA%\copland-ernte.log
param([switch]$Force, [string]$Tag = '')

$ErrorActionPreference = 'SilentlyContinue'
. (Join-Path $PSScriptRoot 'copland-shared.ps1')
$log = Join-Path $CacheDir 'copland-ernte.log'
function Log($m) { "$(Get-Date -Format 'yyyy-MM-dd HH:mm') $m" | Out-File $log -Append -Encoding utf8 }

$day = if ($Tag) { [datetime]::ParseExact($Tag, 'yyyy-MM-dd', $null) } else { (Get-Date).Date.AddDays(-1) }
$marker = Join-Path $CacheDir ("copland-tagesstart-" + (Get-Date).ToString('yyyy-MM-dd'))
if (-not $Force -and (Test-Path $marker)) { exit }
if (-not $Force) { New-Item -ItemType File -Path $marker -Force | Out-Null }
# alte marker wegraeumen
Get-ChildItem $CacheDir -Filter 'copland-tagesstart-*' | Where-Object { $_.Name -ne (Split-Path $marker -Leaf) } | Remove-Item -Force

$brain = Join-Path $OD '60_assistent/brain'
if (-not (Test-Path $brain)) { Log "kein brain-ordner ($brain) -- abbruch"; exit }
if (-not (Get-Command claude -ErrorAction SilentlyContinue)) { Log 'claude nicht gefunden'; exit }

# --- transkripte von $day einsammeln: nur user/assistant-text, max 20k zeichen ---
$sb = New-Object System.Text.StringBuilder
$maxChars = 20000
$files = Get-ChildItem (Join-Path $ClaudeHome 'projects') -Recurse -File -Filter *.jsonl |
    Where-Object { $_.LastWriteTime.Date -eq $day.Date -or ($_.CreationTime.Date -eq $day.Date) } |
    Sort-Object LastWriteTime
if (-not $files) { Log "keine sessions am $($day.ToString('yyyy-MM-dd')) -- nur state"; Start-Hidden (Join-Path $CoplandDir 'copland-state.ps1'); exit }
$perFile = [math]::Max(1500, [int]($maxChars / $files.Count))
foreach ($f in $files) {
    $proj = ($f.Directory.Name -replace ('^' + [regex]::Escape($ODMangled)), '') -replace '^c--users-[a-z0-9]+-', '~/'
    [void]$sb.AppendLine("### session: $proj ($($f.LastWriteTime.ToString('HH:mm')))")
    $acc = 0
    foreach ($ln in (Get-Content $f.FullName -Encoding utf8)) {
        if ($acc -ge $perFile) { break }
        if ($ln -notmatch '"type":"(user|assistant)"') { continue }
        $o = $null; try { $o = $ln | ConvertFrom-Json } catch { continue }
        if (-not $o -or -not $o.message) { continue }
        $role = $o.type
        $txt = ''
        $c = $o.message.content
        if ($c -is [string]) { $txt = $c }
        else { foreach ($part in $c) { if ($part.type -eq 'text' -and $part.text) { $txt += $part.text + ' ' } } }
        $txt = ($txt -replace '\s+', ' ').Trim()
        if (-not $txt -or $txt -match '^<(local-command|command-|system-reminder)') { continue }
        if ($txt.Length -gt 600) { $txt = $txt.Substring(0, 600) + '~' }
        [void]$sb.AppendLine("${role}: $txt")
        $acc += $txt.Length
    }
    [void]$sb.AppendLine('')
}
$inp = Join-Path $CacheDir 'copland-ernte-input.txt'
$sb.ToString() | Set-Content $inp -Encoding utf8
Log "ernte $($day.ToString('yyyy-MM-dd')): $($files.Count) sessions, $($sb.Length) zeichen -> claude -p"

$prompt = @"
Tagesstart-Ernte fuer $($day.ToString('yyyy-MM-dd')). Du arbeitest im Bereich 60_assistent (Personal Assistant des Nutzers).
Lies $inp (gekuerzte Transkripte aller Sessions von gestern, nur user/assistant-Text).
Destilliere daraus NUR projektuebergreifendes Querwissen und trage es ins Brain ein (Dateien in $brain,
Format steht im Kopf jeder Datei, eine datierte Zeile pro Fakt, vorher lesen und deduplizieren):
- personen.md: neue/veraenderte Personen (name | rolle | kontext | zuletzt)
- entscheidungen.md: Entscheidungen des Nutzers (auch verworfene Wege mit Grund), append
- vorlieben.md: Vorlieben/Korrekturen zum Arbeitsstil (alte Zeile ersetzen)
- laufend.md: offene Faeden quer durch Bereiche (append; erledigte Zeilen loeschen; max ~15 Zeilen)
Fristen/Termine mit Datum zusaetzlich nach $(Join-Path $OD '60_assistent/erinnerungen.md') (Format dort ansehen).
Fachwissen, das eine eigene Notiz verdient (Konzepte, Erkenntnisse quer zu Projekten -- selten, max 1-2 pro Ernte):
als Markdown-Notiz in den Vault des passenden Bereichs: <bereich>/vault (10_uni, 30_venture, 00_System fuer systemwissen,
sonst 60_assistent; NIE 40_private). Stil der dortigen Notizen (dateiname klein-mit-bindestrichen, [[wikilinks]] auf
verwandte Notizen setzen, bestehende Notizen lieber ergaenzen als neue anlegen).
Nichts erfinden, nichts Projektinternes (das steht in den Projekt-CLAUDE.mds). Keine anderen Dateien anfassen.
Danach ausfuehren: powershell -NoProfile -ExecutionPolicy Bypass -File "$(Join-Path $CoplandDir 'copland-state.ps1')"
Antworte am Ende mit maximal 5 Zeilen: was eingetragen wurde.
"@
Set-Location (Join-Path $OD '60_assistent')
$out = & claude -p $prompt --permission-mode bypassPermissions --add-dir $SysDir --add-dir $CacheDir 2>&1
Log ("ergebnis: " + (($out | Out-String) -replace '\s+', ' ').Trim())
