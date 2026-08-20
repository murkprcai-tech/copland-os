# COPLAND OS -- Subagent-Statusline (Agent-Panel, pure ASCII)
# pro Task eine JSON-Zeile: {"id":"...","content":"name | status | tok | mm:ss"}

$ErrorActionPreference = 'SilentlyContinue'
$raw = [Console]::In.ReadToEnd()
$j = $raw | ConvertFrom-Json

$E   = [char]27
$FG  = "$E[38;2;184;196;206m"
$AC  = "$E[38;2;140;171;198m"
$DIM = "$E[38;2;74;88;102m"
$R   = "$E[0m"
$SEP = " ${DIM}|${R} "

foreach ($t in $j.tasks) {
    $name = "$($t.name)".ToLower()
    $col = if ($t.status -eq 'running') { $AC } else { $DIM }
    $parts = @("${FG}${name}${R}", "${col}$($t.status)${R}")
    if ($t.tokenCount) {
        $tok = if ($t.tokenCount -ge 1000) { ('{0:N0}k' -f ($t.tokenCount / 1000)) } else { "$($t.tokenCount)" }
        $parts += "${DIM}${tok} tok${R}"
    }
    if ($t.startTime) {
        $el = [DateTimeOffset]::Now.ToUnixTimeMilliseconds() - [long]$t.startTime
        if ($el -ge 0) {
            $mm = [math]::Floor($el / 60000)
            $ss = [math]::Floor(($el % 60000) / 1000)
            $parts += ('{0}{1:00}:{2:00}{3}' -f $DIM, $mm, $ss, $R)
        }
    }
    @{ id = $t.id; content = ($parts -join $SEP) } | ConvertTo-Json -Compress
}
