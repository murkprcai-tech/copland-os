# COPLAND OS -- gemeinsame konstanten (farben)
#
# ACHTUNG: ps-variablen sind case-insensitiv. die namen E, FG, AC, DIM, WARN, R
# sind hiermit reserviert -- NIE als laufvariablen o.ae. verwenden ($r zerstoert $R,
# das gab schon dreimal kaputte anzeigen: wetter, hub-rendering, hauptmenue).
# wird von copland.ps1 und copland-panel.ps1 dot-sourced.
# ausnahme: die statuslines in ~\.claude tragen eine eigene kopie,
# damit sie auch ohne onedrive-zugriff funktionieren.

$E    = [char]27
$FG   = "$E[38;2;184;196;206m"   # grundton
$AC   = "$E[38;2;140;171;198m"   # akzent
$DIM  = "$E[38;2;74;88;102m"     # gedimmt
$WARN = "$E[38;2;194;132;143m"   # warnung
$R    = "$E[0m"

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
