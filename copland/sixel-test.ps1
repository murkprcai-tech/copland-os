# COPLAND OS -- sixel-test: echte pixelgrafik im terminal (WT >= 1.22)
# ausfuehren in einem shell-tab: [0] im launcher, dann:
#   & "$env:USERPROFILE\OneDrive\00_System\copland\sixel-test.ps1"

Import-Module Sixel -ErrorAction Stop
$OD = "$env:USERPROFILE\OneDrive"

Write-Host ""
Write-Host "  sixel-test 1: das lain-ascii-wallpaper als echtes bild"
Write-Host ""
ConvertTo-Sixel -Path "$OD\00_System\copland\lain-wallpaper.png" -Width 60

Write-Host ""
Write-Host "  sixel-test 2: token-verbrauch als echtes diagramm (30 tage)"
Write-Host ""
# chart als png rendern, dann als sixel ausgeben
Add-Type -AssemblyName System.Drawing
$days = @()
try { $days = @((ccusage daily --json 2>$null | ConvertFrom-Json).daily | Select-Object -Last 30) } catch { }
if ($days) {
    $w = 640; $h = 240
    $bmp = New-Object System.Drawing.Bitmap([int]$w, [int]$h)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = 'AntiAlias'
    $g.Clear([System.Drawing.Color]::Black)
    $ac  = [System.Drawing.Color]::FromArgb(255, 140, 171, 198)
    $dim = [System.Drawing.Color]::FromArgb(255, 74, 88, 102)
    $penA = New-Object System.Drawing.Pen($ac, 2)
    $penD = New-Object System.Drawing.Pen($dim, 1)
    $max = ($days | Measure-Object totalTokens -Maximum).Maximum
    $g.DrawLine($penD, 20, $h - 20, $w - 10, $h - 20)
    $pts = @()
    for ($i = 0; $i -lt $days.Count; $i++) {
        $x = 20 + $i / [math]::Max(1, $days.Count - 1) * ($w - 40)
        $y = ($h - 25) - ($days[$i].totalTokens / $max) * ($h - 50)
        $pts += New-Object System.Drawing.PointF([float]$x, [float]$y)
    }
    if ($pts.Count -ge 2) { $g.DrawLines($penA, $pts) }
    foreach ($p in $pts) { $g.FillEllipse((New-Object System.Drawing.SolidBrush($ac)), $p.X - 2, $p.Y - 2, 4, 4) }
    $g.Dispose()
    $tmp = "$env:TEMP\copland-sixel-chart.png"
    $bmp.Save($tmp, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
    ConvertTo-Sixel -Path $tmp -Width 80
} else {
    Write-Host "  (ccusage-daten nicht verfuegbar)"
}
Write-Host ""
Write-Host "  wenn beides als BILD (nicht als zeichensalat) erscheint, kann dein"
Write-Host "  terminal sixel -- sag claude bescheid, was du davon willst."
