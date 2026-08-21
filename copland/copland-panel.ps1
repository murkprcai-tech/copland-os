# COPLAND OS -- Panel (rechts, reine anzeige)
# grosse uhr + ort + claude (modell/ctx/limits) + codex + system
# daten: <cache>/copland-limits.json + copland-sessions/*.json
# (cache = %LOCALAPPDATA% auf windows, ~/.cache/copland auf macos/linux)
# refresh: 60s. [q] schliesst.

$ErrorActionPreference = 'SilentlyContinue'

# farben + plattform gemeinsam mit dem launcher
. (Join-Path $PSScriptRoot 'copland-shared.ps1')
$Cache = Join-Path $CacheDir 'copland-limits.json'
$SDir  = Join-Path $CacheDir 'copland-sessions'

$SEPLINE = "$DIM  .....................$R"

function BigClock {
    Write-Host "$AC  $(Get-Date -Format 'HH:mm')$R"
}

function Bar([double]$p, [int]$w) {
    $f = [math]::Round($p / 100 * $w)
    if ($f -gt $w) { $f = $w }
    if ($f -lt 0)  { $f = 0 }
    ('=' * $f) + ('.' * ($w - $f))
}

# countdown "in 1h 12m" / "in 2t 3h"
function RelTime([long]$epoch) {
    $span = [DateTimeOffset]::FromUnixTimeSeconds($epoch).ToLocalTime() - (Get-Date)
    if ($span.TotalMinutes -lt 1) { return 'jetzt' }
    if ($span.TotalDays -ge 1) { return "in $([math]::Floor($span.TotalDays))t $($span.Hours)h" }
    if ($span.TotalHours -ge 1) { return "in $([math]::Floor($span.TotalHours))h $($span.Minutes)m" }
    return "in $([math]::Floor($span.TotalMinutes))m"
}

# zeile im label-raster: label dim (7 breit), dann wert
function Row([string]$label, [string]$value) {
    Write-Host "$DIM  $($label.PadRight(7))$R$value"
}
function SubRow([string]$value) {
    Write-Host "$DIM         $value$R"
}

# 60s auf taste warten: q = ende, g = grafik-sprung, pfeile = seite wechseln
function Wait-PanelKey {
    $t0 = Get-Date
    while (((Get-Date) - $t0).TotalSeconds -lt 60) {
        if ([Console]::KeyAvailable) {
            $ki = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
            if ("$($ki.Character)" -match '^[qQ]$') { exit }
            if ("$($ki.Character)" -match '^[gG]$') { return 'g' }
            if ($ki.VirtualKeyCode -eq 37) { return 'left' }
            if ($ki.VirtualKeyCode -eq 39) { return 'right' }
        }
        Start-Sleep -Milliseconds 250
    }
    'tick'
}

# burn-rate-historie (5h-fenster) im speicher dieses panels
$hist = New-Object System.Collections.Generic.List[object]

# wetter (wttr.in, standort per ip): gemeinsamer datei-cache fuer alle panels,
# refresh 30 min, fehlversuche fruehestens nach 5 min wiederholen, faellt still aus
$wxFile = Join-Path $CacheDir 'copland-wx.txt'
$wxTry  = Get-Date '2000-01-01'

# codex-limits nur neu parsen, wenn sich das session-log geaendert hat
$cxSeen = $null
$cxRL   = $null

# usage-api (modell-spezifische limits, z.b. fable-wochenfenster):
# datei-cache 5 min, fehlversuche fruehestens nach 2 min, faellt still aus
$usFile = Join-Path $CacheDir 'copland-usage.json'
$usTry  = Get-Date '2000-01-01'

# ki-status (stoerungen anthropic/openai) + neueste releases (claude code, codex):
# datei-cache 15 min, fehlversuche fruehestens nach 5 min, faellt still aus
$aiFile = Join-Path $CacheDir 'copland-ai-status.json'
$aiTry  = Get-Date '2000-01-01'

# sixel-minicharts (token-kurve 30d + aktivitaets-heatmap): stuendlich neu gebaut,
# faellt still aus, wenn das sixel-modul fehlt oder ccusage nicht antwortet.
# system.drawing gibt es nur auf windows -> auf macos/linux bleibt die grafikseite leer
$SixelOn = $false
if ($IsWin) { try { Import-Module Sixel -ErrorAction Stop; Add-Type -AssemblyName System.Drawing; $SixelOn = $true } catch { } }
$sxTs = Get-Date '2000-01-01'
$sxChart = $null
$sxHeat  = $null
$sxModel = $null
$sxModelLegend = ''
$page = 1   # 1 = limits, 2 = grafik. pfeiltasten wechseln, g/alt+g springt zur grafik

while ($true) {
    Clear-Host
    Write-Host ""
    BigClock
    $wxCached = (Test-Path $wxFile) -and (((Get-Date) - (Get-Item $wxFile).LastWriteTime).TotalMinutes -lt 30)
    if (-not $wxCached -and ((Get-Date) - $wxTry).TotalMinutes -ge 5) {
        $wxTry = Get-Date
        try {
            # NICHT $r nennen -- ps-variablen sind case-insensitiv, $R ist der ansi-reset
            $wxResp = Invoke-RestMethod 'https://wttr.in/?format=%t+%C&lang=de' -TimeoutSec 5
            if ("$wxResp" -and "$wxResp" -notmatch 'Unknown|error') {
                # grad-zeichen raus (ascii-regel): "+30(grad)C" -> "30c"
                Set-Content $wxFile ("$wxResp".Trim().ToLower() -replace '^\+', '' -replace [char]176, '')
            }
        } catch { }
    }
    $wx = if (Test-Path $wxFile) { Get-Content $wxFile -TotalCount 1 } else { '' }
    $usStale = -not (Test-Path $usFile) -or ((Get-Date) - (Get-Item $usFile).LastWriteTime).TotalMinutes -ge 5
    if ($usStale -and ((Get-Date) - $usTry).TotalMinutes -ge 2) {
        $usTry = Get-Date
        try {
            $tok = Get-ClaudeToken
            if ($tok) {
                $usResp = Invoke-RestMethod 'https://api.anthropic.com/api/oauth/usage' `
                    -Headers @{ Authorization = "Bearer $tok"; 'anthropic-beta' = 'oauth-2025-04-20' } -TimeoutSec 8
                $usResp | ConvertTo-Json -Depth 8 -Compress | Set-Content $usFile -Encoding utf8
            }
        } catch { }
    }
    $aiStale = -not (Test-Path $aiFile) -or ((Get-Date) - (Get-Item $aiFile).LastWriteTime).TotalMinutes -ge 15
    if ($aiStale -and ((Get-Date) - $aiTry).TotalMinutes -ge 5) {
        $aiTry = Get-Date
        $ai = @{}
        try { $ai.anthropic = (Invoke-RestMethod 'https://status.anthropic.com/api/v2/status.json' -TimeoutSec 5).status } catch { }
        try { $ai.openai = (Invoke-RestMethod 'https://status.openai.com/api/v2/status.json' -TimeoutSec 5).status } catch { }
        try { $ai.cc = (Invoke-RestMethod 'https://api.github.com/repos/anthropics/claude-code/releases/latest' -TimeoutSec 5).tag_name } catch { }
        try { $ai.codex = (Invoke-RestMethod 'https://api.github.com/repos/openai/codex/releases/latest' -TimeoutSec 5).tag_name } catch { }
        if ($ai.Count) { $ai | ConvertTo-Json -Compress | Set-Content $aiFile -Encoding utf8 }
    }
    $aiData = if (Test-Path $aiFile) { Get-Content $aiFile -Raw | ConvertFrom-Json } else { $null }
    if ($SixelOn -and $page -eq 2 -and ((Get-Date) - $sxTs).TotalMinutes -ge 60) {
        $sxTs = Get-Date
        try {
            # token-kurve 30 tage: claude (akzent) + codex/gpt (mittelblau), flaeche = gesamt
            $days = @((ccusage daily --json 2>$null | ConvertFrom-Json).daily | Select-Object -Last 30)
            if ($days.Count -ge 2) {
                $cw = 360; $ch = 70
                $bmp = New-Object System.Drawing.Bitmap([int]$cw, [int]$ch)
                $g = [System.Drawing.Graphics]::FromImage($bmp)
                $g.SmoothingMode = 'AntiAlias'
                $g.Clear([System.Drawing.Color]::Black)
                $acC  = [System.Drawing.Color]::FromArgb(255, 140, 171, 198)
                $gptC = [System.Drawing.Color]::FromArgb(255, 110, 140, 166)
                $dimC = [System.Drawing.Color]::FromArgb(255, 30, 40, 50)
                $cl = @(); $gp = @()
                foreach ($dd2 in $days) {
                    $c2 = 0; $g2t = 0
                    foreach ($mb in $dd2.modelBreakdowns) {
                        $tokSum = [double]$mb.inputTokens + [double]$mb.outputTokens +
                                  [double]$mb.cacheCreationTokens + [double]$mb.cacheReadTokens
                        if ("$($mb.modelName)" -like 'claude*') { $c2 += $tokSum } else { $g2t += $tokSum }
                    }
                    $cl += $c2; $gp += $g2t
                }
                $mx = (($cl + $gp) | Measure-Object -Maximum).Maximum
                if ($mx -le 0) { $mx = 1 }
                function _pts([double[]]$vv) {
                    $o = @()
                    for ($i = 0; $i -lt $vv.Count; $i++) {
                        $x = 4 + $i / ($vv.Count - 1) * ($cw - 8)
                        $y = ($ch - 5) - ($vv[$i] / $mx) * ($ch - 10)
                        $o += New-Object System.Drawing.PointF([float]$x, [float]$y)
                    }
                    , $o
                }
                $pC = _pts $cl
                $poly = $pC + (New-Object System.Drawing.PointF([float]($cw - 4), [float]($ch - 3))) +
                        (New-Object System.Drawing.PointF([float]4, [float]($ch - 3)))
                $g.FillPolygon((New-Object System.Drawing.SolidBrush($dimC)), $poly)
                if (($gp | Measure-Object -Maximum).Maximum -gt 0) {
                    $g.DrawLines((New-Object System.Drawing.Pen($gptC, 1)), (_pts $gp))
                }
                $g.DrawLines((New-Object System.Drawing.Pen($acC, 2)), $pC)
                $g.Dispose()
                $tmp = Join-Path $env:TEMP 'copland-panel-usage.png'
                $bmp.Save($tmp, [System.Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose()
                $sxChart = ConvertTo-Sixel -Path $tmp -Width 18
            }
            # modell-split: wer frisst das budget? (kosten 30d, eine gestapelte leiste)
            if ($days.Count -ge 1) {
                $fam = [ordered]@{ fable = 0.0; opus = 0.0; sonnet = 0.0; haiku = 0.0; gpt = 0.0 }
                foreach ($dd2 in $days) {
                    foreach ($mb in $dd2.modelBreakdowns) {
                        $n2 = "$($mb.modelName)"
                        $k2 = if ($n2 -like '*fable*') { 'fable' } elseif ($n2 -like '*opus*') { 'opus' }
                              elseif ($n2 -like '*sonnet*') { 'sonnet' } elseif ($n2 -like '*haiku*') { 'haiku' }
                              else { 'gpt' }
                        $fam[$k2] += [double]$mb.cost
                    }
                }
                $tot = ($fam.Values | Measure-Object -Sum).Sum
                if ($tot -gt 0) {
                    $mcol = @{
                        fable  = [System.Drawing.Color]::FromArgb(255, 140, 171, 198)
                        opus   = [System.Drawing.Color]::FromArgb(255, 110, 140, 166)
                        sonnet = [System.Drawing.Color]::FromArgb(255, 156, 192, 210)
                        haiku  = [System.Drawing.Color]::FromArgb(255, 74, 88, 102)
                        gpt    = [System.Drawing.Color]::FromArgb(255, 124, 154, 142)
                    }
                    $bw = 360; $bh = 16
                    $bmp3 = New-Object System.Drawing.Bitmap([int]$bw, [int]$bh)
                    $g3 = [System.Drawing.Graphics]::FromImage($bmp3)
                    $g3.Clear([System.Drawing.Color]::Black)
                    $x3 = 0.0
                    $leg = @()
                    foreach ($k2 in $fam.Keys) {
                        $frac = $fam[$k2] / $tot
                        if ($frac -le 0.001) { continue }
                        $seg = $frac * $bw
                        $g3.FillRectangle((New-Object System.Drawing.SolidBrush($mcol[$k2])), [float]$x3, 2, [float]$seg, $bh - 4)
                        $x3 += $seg
                        $leg += "$k2 $([math]::Round($frac * 100))%"
                    }
                    $g3.Dispose()
                    $tmp3 = Join-Path $env:TEMP 'copland-panel-models.png'
                    $bmp3.Save($tmp3, [System.Drawing.Imaging.ImageFormat]::Png); $bmp3.Dispose()
                    $sxModel = ConvertTo-Sixel -Path $tmp3 -Width 18
                    $sxModelLegend = $leg -join '  '
                }
            }
            # aktivitaets-heatmap 16 wochen x 7 tage
            $act = @{}
            Get-ChildItem (Join-Path $ClaudeHome 'projects') -Directory | ForEach-Object {
                Get-ChildItem $_.FullName -File -Filter *.jsonl | ForEach-Object {
                    if ($_.LastWriteTime -gt (Get-Date).AddDays(-112)) {
                        $dk = $_.LastWriteTime.Date.ToString('yyyy-MM-dd')
                        $act[$dk] = [int]$act[$dk] + 1
                    }
                }
            }
            $cell = 10; $gap = 2
            $bmp2 = New-Object System.Drawing.Bitmap([int](16 * ($cell + $gap)), [int](7 * ($cell + $gap)))
            $g2 = [System.Drawing.Graphics]::FromImage($bmp2)
            $g2.Clear([System.Drawing.Color]::Black)
            $today2 = (Get-Date).Date
            $monday2 = $today2.AddDays(-(([int]$today2.DayOfWeek + 6) % 7))
            $hstart2 = $monday2.AddDays(-105)
            for ($wk = 0; $wk -lt 16; $wk++) {
                for ($dw = 0; $dw -lt 7; $dw++) {
                    $dd = $hstart2.AddDays($wk * 7 + $dw)
                    if ($dd -gt $today2) { continue }
                    $v = [int]$act[$dd.ToString('yyyy-MM-dd')]
                    $lvl = if ($v -ge 7) { 4 } elseif ($v -ge 4) { 3 } elseif ($v -ge 2) { 2 } elseif ($v -ge 1) { 1 } else { 0 }
                    $col = switch ($lvl) {
                        0 { [System.Drawing.Color]::FromArgb(255, 18, 24, 30) }
                        1 { [System.Drawing.Color]::FromArgb(255, 42, 59, 76) }
                        2 { [System.Drawing.Color]::FromArgb(255, 63, 90, 115) }
                        3 { [System.Drawing.Color]::FromArgb(255, 95, 130, 160) }
                        4 { [System.Drawing.Color]::FromArgb(255, 140, 171, 198) }
                    }
                    $g2.FillRectangle((New-Object System.Drawing.SolidBrush($col)),
                        $wk * ($cell + $gap), $dw * ($cell + $gap), $cell, $cell)
                }
            }
            $g2.Dispose()
            $tmp2 = Join-Path $env:TEMP 'copland-panel-heat.png'
            $bmp2.Save($tmp2, [System.Drawing.Imaging.ImageFormat]::Png); $bmp2.Dispose()
            $sxHeat = ConvertTo-Sixel -Path $tmp2 -Width 18
        } catch { }
    }
    $usScoped = @()
    if (Test-Path $usFile) {
        $usScoped = @((Get-Content $usFile -Raw | ConvertFrom-Json).limits |
            Where-Object { $_.kind -eq 'weekly_scoped' -and $_.scope.model.display_name })
    }
    $dateline = (Get-Date -Format 'ddd dd.MM.').ToLower()
    if ($wx) {
        $wxS = "$wx"
        if ($wxS.Length -gt 18) { $wxS = $wxS.Substring(0, 17) + '~' }
        $dateline += " | $wxS"
    }
    Write-Host "$DIM  $dateline$R"
    Write-Host ""

    # === seite 2: grafik (pfeiltasten oder g/alt+g wechseln) ===
    if ($page -eq 2) {
        # rat-nutzung heute (anfragen je stimme): billig, bei jedem aufruf frisch
        $sxRat = $null
        $ruf2 = Join-Path $CacheDir 'copland-rat-usage.json'
        if ($SixelOn -and (Test-Path $ruf2)) {
            try {
                $ru2 = Get-Content $ruf2 -Raw | ConvertFrom-Json
                if ($ru2.date -eq (Get-Date -Format 'yyyy-MM-dd')) {
                    $vv = @()
                    foreach ($vn in 'nemotron', 'groq', 'qwen', 'gemini', 'mistral') {
                        $val = if ($ru2.PSObject.Properties.Name -contains $vn) { [int]$ru2.$vn } else { 0 }
                        if ($val -gt 0) { $vv += , @($vn, $val) }
                    }
                    if ($vv) {
                        $rh = $vv.Count * 18 + 4; $rw = 360
                        $bmp4 = New-Object System.Drawing.Bitmap([int]$rw, [int]$rh)
                        $g4 = [System.Drawing.Graphics]::FromImage($bmp4)
                        $g4.Clear([System.Drawing.Color]::Black)
                        $fnt = New-Object System.Drawing.Font('Consolas', 10)
                        $acB = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 140, 171, 198))
                        $fgB = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 184, 196, 206))
                        $vmax = ($vv | ForEach-Object { $_[1] } | Measure-Object -Maximum).Maximum
                        for ($i = 0; $i -lt $vv.Count; $i++) {
                            $y4 = 2 + $i * 18
                            $g4.DrawString($vv[$i][0], $fnt, $fgB, 2, $y4)
                            $bl = [math]::Max(4, $vv[$i][1] / $vmax * 230)
                            $g4.FillRectangle($acB, 80, $y4 + 3, [float]$bl, 9)
                            $g4.DrawString("$($vv[$i][1])", $fnt, $fgB, [float](86 + $bl), $y4)
                        }
                        $g4.Dispose()
                        $tmp4 = Join-Path $env:TEMP 'copland-panel-rat.png'
                        $bmp4.Save($tmp4, [System.Drawing.Imaging.ImageFormat]::Png); $bmp4.Dispose()
                        $sxRat = ConvertTo-Sixel -Path $tmp4 -Width 18
                    }
                }
            } catch { }
        }
        Write-Host $SEPLINE
        Write-Host ""
        if ($sxChart) {
            Write-Host "$DIM  tokens 30d  $R$AC claude$R$DIM / codex$R"
            Write-Host $sxChart
        }
        if ($sxModel) {
            Write-Host "$DIM  modelle 30d (kosten)$R"
            Write-Host $sxModel
            Write-Host "$DIM  $sxModelLegend$R"
        }
        if ($sxRat) {
            Write-Host "$DIM  rat heute (anfragen)$R"
            Write-Host $sxRat
        }
        if ($sxHeat) {
            Write-Host "$DIM  aktivitaet 16w$R"
            Write-Host $sxHeat
        }
        if (-not ($sxChart -or $sxModel -or $sxHeat -or $sxRat)) { Write-Host "$DIM  (keine grafik-daten)$R" }
        Write-Host ""
        Write-Host "$DIM  limits $R$AC< grafik >$R$DIM  [alt+g]$R"
        $act = Wait-PanelKey
        if ($act -ne 'tick') { $page = 1 }
        continue
    }

    $c = $null
    if (Test-Path $Cache) { $c = Get-Content $Cache -Raw | ConvertFrom-Json }
    $fresh = $c -and ([DateTimeOffset]::Now.ToUnixTimeSeconds() - [long]$c.ts) -lt 900

    if ($fresh) {
        # --- ort ---
        $W = $Host.UI.RawUI.WindowSize.Width - 4
        if ($c.area) { Write-Host "$AC  $($c.area)$R" }
        if ($c.dir) {
            $d = "$($c.dir)"
            if ($d.Length -gt $W) { $d = '~' + $d.Substring($d.Length - $W + 1) }
            Write-Host "$DIM  $d$R"
        }
        Write-Host ""
        Write-Host $SEPLINE
        Write-Host ""

        # --- claude ---
        $eff = ''
        if ($c.effort) { $eff = " $DIM[$($c.effort)]$R" }
        $mdlName = "$($c.model)"
        if ($mdlName.Length -gt 12) { $mdlName = $mdlName.Substring(0, 11) + '~' }
        Row 'claude' "$FG$mdlName$R$eff"
        if ($null -ne $c.ctx) {
            $col = if ($c.ctx -ge 80) { $WARN } else { $FG }
            Row 'ctx' "$col$($c.ctx)%$R"
            if ($c.ctx -ge 80) { SubRow 'ctx hoch -> /compact' }
        }
        Write-Host ""

        # --- 5h-limit: burn-rate mitschreiben ---
        $p5 = $null
        if ($c.five_hour -and $null -ne $c.five_hour.used_percentage) {
            $p5 = [double]$c.five_hour.used_percentage
            $hist.Add(@{ t = (Get-Date); p = $p5 })
            while ($hist.Count -gt 30) { $hist.RemoveAt(0) }
        }

        # --- limits ---
        foreach ($pair in @(@('5h', $c.five_hour), @('7d', $c.seven_day))) {
            $win = $pair[1]
            if ($win -and $null -ne $win.used_percentage) {
                $p = [math]::Round($win.used_percentage)
                $col = if ($p -ge 80) { $WARN } else { $FG }
                Row $pair[0] "$col[$(Bar $p 12)] $p%$R"
                $info = ''
                $prog = ''
                if ($win.resets_at) { $info = "reset $(RelTime ([long]$win.resets_at))" }
                # prognose nur fuers 5h-fenster, ab 10 min historie und steigendem verbrauch
                if ($pair[0] -eq '5h' -and $hist.Count -ge 2) {
                    $old = $hist | Where-Object { ((Get-Date) - $_.t).TotalMinutes -ge 10 } | Select-Object -Last 1
                    if (-not $old) { $old = $hist[0] }
                    $dt = ((Get-Date) - $old.t).TotalMinutes
                    if ($dt -ge 5 -and $p5 -gt $old.p) {
                        $rate = ($p5 - $old.p) / $dt
                        if ($rate -gt 0.05 -and $p5 -lt 100) {
                            $leer = (Get-Date).AddMinutes((100 - $p5) / $rate)
                            $prog = "leer ~$($leer.ToString('HH:mm'))"
                        }
                    }
                }
                if ($info) { SubRow $info }
                if ($prog) { SubRow $prog }
                # burn-kurve: 5h-verlauf der letzten ~30 min (braille, sonst ascii)
                if ($pair[0] -eq '5h' -and $hist.Count -ge 8 -and $p5 -ge 40) {
                    $pts = @($hist | Select-Object -Last 18 | ForEach-Object { [double]$_.p })
                    $bc = ConvertTo-BrailleChart $pts 18 3 100
                    if ($bc) {
                        foreach ($bl in $bc) { SubRow $bl }
                    } else {
                        for ($cr = 0; $cr -lt 3; $cr++) {
                            $hi = 100 - $cr * 33.4; $lo = $hi - 33.3
                            $cl = ''
                            foreach ($pt in $pts) {
                                $cl += if ($pt -gt $hi) { ':' } elseif ($pt -gt $lo) { '*' } else { ' ' }
                            }
                            SubRow $cl
                        }
                    }
                }
                Write-Host ""
            }
        }
        # modell-spezifische wochenfenster (z.b. fable) aus der usage-api
        foreach ($sl in $usScoped) {
            $p = [math]::Round($sl.percent)
            $col = if ($p -ge 80) { $WARN } else { $FG }
            $lbl = "$($sl.scope.model.display_name)".ToLower()
            if ($lbl.Length -gt 7) { $lbl = $lbl.Substring(0, 7) }
            Row $lbl "$col[$(Bar $p 12)] $p%$R"
            if ($sl.resets_at) {
                SubRow "reset $(RelTime ([DateTimeOffset]::Parse($sl.resets_at).ToUnixTimeSeconds()))"
            }
            Write-Host ""
        }
    } else {
        Write-Host "$DIM  --$R"
        Write-Host ""
    }

    # --- codex-limits (aus dem juengsten session-log von codex) ---
    $cxFile = Get-ChildItem (Join-Path $env:USERPROFILE '.codex/sessions') -Recurse -File -Filter *.jsonl |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($cxFile -and $cxFile.LastWriteTime -ne $cxSeen) {
        # nur bei geaendertem log neu scannen -- die datei waechst waehrend codex laeuft
        $cxSeen = $cxFile.LastWriteTime
        $rlLine = (Select-String -Path $cxFile.FullName -Pattern '"rate_limits"' | Select-Object -Last 1).Line
        $cxRL = if ($rlLine) { ($rlLine | ConvertFrom-Json).payload.rate_limits } else { $null }
    }
    if ($cxRL) {
            $wins = @($cxRL.primary, $cxRL.secondary) | Where-Object { $_ -and $null -ne $_.used_percent }
            if ($wins) {
                Write-Host $SEPLINE
                Write-Host ""
                $plan = ''
                if ($cxRL.plan_type) { $plan = " $DIM[$($cxRL.plan_type)]$R" }
                Row 'codex' "${FG}gpt$R$plan"
                foreach ($w in $wins) {
                    $lbl = switch ([int]$w.window_minutes) {
                        300     { '5h' }
                        10080   { '7d' }
                        43200   { '30d' }
                        default { "$([math]::Round($w.window_minutes/1440))d" }
                    }
                    $p = [math]::Round($w.used_percent)
                    $col = if ($p -ge 80) { $WARN } else { $FG }
                    Row $lbl "$col[$(Bar $p 12)] $p%$R"
                    if ($w.resets_at) { SubRow "reset $(RelTime ([long]$w.resets_at))" }
                }
                Write-Host ""
            }
    }

    # --- rat (freie ki-stimmen): gleiche optik wie claude/codex, balken = tageslimit ---
    $ratVoices = @(
        @{ env = 'OPENROUTER_API_KEY'; cnt = 'nemotron'; lbl = 'nvidia';  limit = 50;   info = 'denker' },
        @{ env = 'GROQ_API_KEY';       cnt = 'groq';     lbl = 'groq';    limit = 1000; info = 'llama' },
        @{ env = 'GROQ_API_KEY';       cnt = 'qwen';     lbl = 'qwen';    limit = 1000; info = 'alibaba' },
        @{ env = 'GEMINI_API_KEY';     cnt = 'gemini';   lbl = 'gemini';  limit = 1500; info = 'google' },
        @{ env = 'MISTRAL_API_KEY';    cnt = 'mistral';  lbl = 'mistral'; limit = 500;  info = 'eu' }
    )
    $ratActive = @($ratVoices | Where-Object { Get-UserEnv $_.env })
    if ($ratActive) {
        $ruf = Join-Path $CacheDir 'copland-rat-usage.json'
        $ru = if (Test-Path $ruf) { Get-Content $ruf -Raw | ConvertFrom-Json } else { $null }
        $ruToday = ($ru -and $ru.date -eq (Get-Date -Format 'yyyy-MM-dd'))
        Write-Host $SEPLINE
        Write-Host ""
        Row 'rat' "${FG}frei$R $DIM[0 eur]$R"
        # schwellwert-prinzip: nur stimmen zeigen, die heute benutzt wurden
        $ratShown = 0
        foreach ($rv in $ratActive) {
            $n = 0
            if ($ruToday -and ($ru.PSObject.Properties.Name -contains $rv.cnt)) { $n = [int]$ru.($rv.cnt) }
            if ($n -le 0) { continue }
            $ratShown++
            $p = [math]::Round($n / $rv.limit * 100)
            $col = if ($p -ge 80) { $WARN } else { $FG }
            Row $rv.lbl "$col[$(Bar $p 12)] $p%$R"
            SubRow "$($rv.info) $n/$($rv.limit)"
        }
        if ($ratShown -eq 0) { SubRow "$($ratActive.Count) stimmen bereit" }
        Write-Host ""
    }

    # --- aktive sessions (nur wenn mehr als eine) ---
    $sess = @()
    if (Test-Path $SDir) {
        $sess = Get-ChildItem $SDir -File |
            Where-Object { $_.LastWriteTime -gt (Get-Date).AddMinutes(-3) } |
            ForEach-Object { Get-Content $_.FullName -Raw | ConvertFrom-Json }
    }
    if ($sess.Count -gt 1) {
        Write-Host $SEPLINE
        Write-Host ""
        foreach ($s in ($sess | Sort-Object area)) {
            $n = "$($s.name)"
            if ($n.Length -gt 14) { $n = $n.Substring(0, 13) + '~' }
            Row 'tab' "$AC$(("$($s.area)").PadRight(9))$R$DIM $n$R"
        }
        Write-Host ""
    }

    # --- system-einzeiler (windows: cim | macos: sysctl+vm_stat | linux: /proc/meminfo) ---
    $ram = $null
    if ($IsWin) {
        $freeGB = [math]::Round((Get-PSDrive C).Free / 1GB)
        $os = Get-CimInstance Win32_OperatingSystem
        $ram = [math]::Round(100 - ($os.FreePhysicalMemory / $os.TotalVisibleMemorySize * 100))
        $sysLine = "c: $freeGB gb frei"
    } else {
        $freeGB = [math]::Round((New-Object IO.DriveInfo '/').AvailableFreeSpace / 1GB)
        $sysLine = "/: $freeGB gb frei"
        if ($IsMac) {
            $memTot = [double](& sysctl -n hw.memsize 2>$null)
            $vm = @(& vm_stat 2>$null)
            $pgSz = 4096.0
            if ($vm.Count -and "$($vm[0])" -match 'page size of (\d+)') { $pgSz = [double]$Matches[1] }
            $memFree = 0.0
            foreach ($vl in $vm) { if ($vl -match '^Pages (free|inactive|speculative):\s+(\d+)') { $memFree += [double]$Matches[2] * $pgSz } }
            if ($memTot -gt 0) { $ram = [math]::Round(100 - $memFree / $memTot * 100) }
        } elseif (Test-Path '/proc/meminfo') {
            $memTot = 0.0; $memAv = 0.0
            foreach ($vl in (Get-Content '/proc/meminfo')) {
                if ($vl -match '^MemTotal:\s+(\d+)') { $memTot = [double]$Matches[1] }
                if ($vl -match '^MemAvailable:\s+(\d+)') { $memAv = [double]$Matches[1] }
            }
            if ($memTot -gt 0) { $ram = [math]::Round(100 - $memAv / $memTot * 100) }
        }
    }
    if ($null -ne $ram) { $sysLine += " | ram $ram%" }
    Write-Host $SEPLINE
    Write-Host ""
    Write-Host "$DIM  $sysLine$R"

    # --- ki-dienste: stoerungen nur wenn etwas klemmt, releases als stille zeile ---
    if ($aiData) {
        foreach ($svc in @(@('anthropic', $aiData.anthropic), @('openai', $aiData.openai))) {
            if ($svc[1] -and $svc[1].indicator -and $svc[1].indicator -ne 'none') {
                $sdesc = "$($svc[1].description)".ToLower()
                if ($sdesc.Length -gt 18) { $sdesc = $sdesc.Substring(0, 17) + '~' }
                Write-Host "$WARN  $($svc[0]): $sdesc$R"
            }
        }
        # release-zeile nur, wenn ein claude-code-update aussteht (schwellwert-prinzip)
        $cc = "$($aiData.cc)" -replace '^v', ''
        if ($cc -and $c -and $c.ccv -and $cc -ne "$($c.ccv)") {
            Write-Host "$DIM  update verfuegbar: cc $cc$R"
        }
    }

    # --- git-sync je aktivem repo (daten aus den session-dateien) ---
    # nur zeigen, wenn was zu tun ist: konflikt > nachziehen > abgeben
    $gitRows = @{}
    foreach ($s in $sess) {
        if (-not $s.git) { continue }
        if ($gitRows.ContainsKey("$($s.name)")) { continue }
        $g = $s.git
        $line = $null
        if ($g.conflict) {
            $line = "${WARN}konflikt!$R"
        } elseif ([int]$g.behind -gt 0) {
            $tag = "remote+$($g.behind)"
            if ([int]$g.ahead -gt 0) { $tag += " du+$($g.ahead)" }
            $line = "${AC}$tag$R$DIM pull$R"
        } elseif ([int]$g.ahead -gt 0) {
            $line = "${AC}du+$($g.ahead)$R$DIM push$R"
        }
        if ($line) { $gitRows["$($s.name)"] = $line }
    }
    if ($gitRows.Count -gt 0) {
        Write-Host ""
        foreach ($k in ($gitRows.Keys | Sort-Object)) {
            $n = "$k"
            if ($n.Length -gt 8) { $n = $n.Substring(0, 7) + '~' }
            Write-Host "$DIM  $($n.PadRight(9))$R$($gitRows[$k])"
        }
    }

    Write-Host ""
    Write-Host "$AC  < limits >$R$DIM grafik  [alt+g]$R"
    $act = Wait-PanelKey
    if ($act -ne 'tick') { $page = 2 }
}
