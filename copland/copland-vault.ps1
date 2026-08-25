# COPLAND OS -- vault: wissens-notizen im terminal (workspace-screen)
# ein fester bildschirm, drei spalten: liste | notiz | kontext. tippen filtert live,
# pfeile/maus waehlen, die notiz in der mitte folgt sofort (hover-preview), kontext
# (backlinks, ausgehend, aehnlich, tags) bleibt stehen. markdown + [[wikilinks]],
# obsidian-kompatibel (normale .md-dateien in 60_assistent/vault).
# maus: windows terminal/conhost via ReadConsoleInput (klick, rad); sonst tastatur.
# -Html: schreibt die browser-landkarte (force-graph) nach vault/_graph.html und endet.
# aufruf: [v] im launcher oder direkt -File copland-vault.ps1
param([switch]$Html, [string]$Bereich = '')

$ErrorActionPreference = 'SilentlyContinue'
. (Join-Path $PSScriptRoot 'copland-shared.ps1')

# ein vault je lebensbereich: <bereich>/vault (obsidian kann jeden ordner separat oeffnen)
$Vaults = @(
    @{ key = '1'; id = 'uni';     label = 'UNI';     dir = '10_uni' },
    @{ key = '2'; id = 'work';    label = 'WORK';    dir = '20_work' },
    @{ key = '3'; id = 'venture'; label = 'VENTURE'; dir = '30_venture' },
    @{ key = '4'; id = 'privat';  label = 'PRIVATE'; dir = '40_private' },
    @{ key = '5'; id = 'career';  label = 'CAREER';  dir = '50_career' },
    @{ key = 'a'; id = 'alltag';  label = 'ALLTAG';  dir = '60_assistent' },
    @{ key = 's'; id = 'system';  label = 'SYSTEM';  dir = '00_System' }
)
$script:Cur = $null
$VaultDir = ''
function Get-VaultDirOf($v) { Join-Path (Join-Path $OD $v.dir) 'vault' }
function Set-Vault($v) {
    $script:Cur = $v
    $script:VaultDir = Get-VaultDirOf $v
    $script:EmbIndexFile = Join-Path $CacheDir "copland-vault-index-$($v.id).json"
    if (-not (Test-Path $script:VaultDir)) {
        New-Item -ItemType Directory -Path (Join-Path $script:VaultDir 'daily') -Force | Out-Null
        @("# start $($v.label.ToLower())", '', "Vault fuer den bereich $($v.dir). Notizen sind normale Markdown-Dateien,",
          'Verweise gehen per [[notizname]] -- der Dateiname ohne .md zaehlt; links in andere',
          'bereichs-vaults werden beim folgen automatisch aufgeloest.') | Set-Content (Join-Path $script:VaultDir 'start.md') -Encoding utf8
    }
}
function Resolve-Vault([string]$k) { $Vaults | Where-Object { $_.key -eq $k -or $_.id -eq $k -or $_.dir -eq $k } | Select-Object -First 1 }

# ============================================================ daten-schicht

function Get-Notes { @(Get-ChildItem $VaultDir -Recurse -File -Filter *.md | Where-Object { $_.Name -notmatch '^_' } | Sort-Object LastWriteTime -Descending) }

function Resolve-Note([string]$name) {
    $n = $name.Trim()
    $hit = Get-Notes | Where-Object { $_.BaseName -ieq $n } | Select-Object -First 1
    if ($hit) { return $hit }
    # nicht hier: in den anderen bereichs-vaults suchen (rueckgabe traegt .vault)
    foreach ($v in $Vaults) {
        if ($v.id -eq $script:Cur.id) { continue }
        $d = Get-VaultDirOf $v
        if (-not (Test-Path $d)) { continue }
        $h2 = Get-ChildItem $d -Recurse -File -Filter *.md | Where-Object { $_.BaseName -ieq $n } | Select-Object -First 1
        if ($h2) { $h2 | Add-Member -NotePropertyName vault -NotePropertyValue $v -Force; return $h2 }
    }
    $null
}

function Get-RelDate([datetime]$t) {
    if ($t.Date -eq (Get-Date).Date) { 'heute' }
    elseif ($t.Date -eq (Get-Date).Date.AddDays(-1)) { 'gestern' }
    else { "vor $([int]((Get-Date) - $t).TotalDays)t" }
}

# wikilinks einer notiz: [[name]], [[name|alias]], [[name#abschnitt]]
function Get-WikiLinks([string[]]$lines) {
    $found = New-Object System.Collections.ArrayList
    foreach ($ln in $lines) {
        foreach ($m in [regex]::Matches($ln, '\[\[([^\]\|#]+)')) {
            $t = $m.Groups[1].Value.Trim()
            if ($t -and -not ($found -contains $t)) { [void]$found.Add($t) }
        }
    }
    , @($found)
}

# link-index: je notiz ausgehend/eingehend (kleingeschriebene basenames)
function Get-LinkIndex {
    $idx = @{}
    $notes = Get-Notes
    foreach ($f in $notes) { $idx[$f.BaseName.ToLower()] = @{ file = $f; out = @(); in = @() } }
    foreach ($f in $notes) {
        $links = Get-WikiLinks @(Get-Content $f.FullName -Encoding utf8)
        foreach ($lk in $links) {
            $key = $lk.ToLower(); $me = $f.BaseName.ToLower()
            if ($idx.ContainsKey($key) -and $key -ne $me) { $idx[$me].out += $key; $idx[$key].in += $me }
        }
    }
    $idx
}

# #tags je notiz (nicht in code-bloecken, keine ueberschriften)
function Get-NoteTags([string[]]$lines) {
    $tags = New-Object System.Collections.ArrayList
    $inCode = $false
    foreach ($ln in $lines) {
        if ($ln -match '^```') { $inCode = -not $inCode; continue }
        if ($inCode -or $ln -match '^#+\s') { continue }
        foreach ($m in [regex]::Matches($ln, '(?<=^|\s)#([a-z0-9_\-/]+)')) {
            $t = $m.Groups[1].Value.ToLower()
            if (-not ($tags -contains $t)) { [void]$tags.Add($t) }
        }
    }
    , @($tags)
}

function New-Note([string]$name) {
    $safe = $name.Trim() -replace '[\\/:*?"<>|]', '-'
    if (-not $safe) { return $null }
    $np = Join-Path $VaultDir "$safe.md"
    if (-not (Test-Path $np)) { @("# $safe", '', "Angelegt: $(Get-Date -Format 'yyyy-MM-dd')", '') | Set-Content $np -Encoding utf8 }
    Get-Item $np
}

function Get-DailyNote {
    $dp = Join-Path $VaultDir ('daily/' + (Get-Date -Format 'yyyy-MM-dd') + '.md')
    if (-not (Test-Path (Split-Path $dp -Parent))) { New-Item -ItemType Directory -Path (Split-Path $dp -Parent) -Force | Out-Null }
    if (-not (Test-Path $dp)) { @('# ' + (Get-Date -Format 'yyyy-MM-dd'), '', '- ') | Set-Content $dp -Encoding utf8 }
    Get-Item $dp
}

# --- semantik via ollama-embeddings (nomic-embed-text, offline) ---
$EmbModel = 'nomic-embed-text'
$EmbIndexFile = ''   # wird in Set-Vault je bereich gesetzt

function Get-Embedding([string]$text) {
    try {
        $body = @{ model = $EmbModel; input = $text } | ConvertTo-Json -Compress
        $resp = Invoke-RestMethod -Uri 'http://localhost:11434/api/embed' -Method Post -Body $body -ContentType 'application/json' -TimeoutSec 30
        , @($resp.embeddings[0])
    } catch { $null }
}

function Read-EmbIndex {
    $stored = @{}
    if (Test-Path $EmbIndexFile) {
        $raw = Get-Content $EmbIndexFile -Raw | ConvertFrom-Json
        foreach ($prop in $raw.PSObject.Properties) { $stored[$prop.Name] = $prop.Value }
    }
    $stored
}

# inkrementell: nur neue/geaenderte notizen einbetten. $null wenn ollama fehlt.
function Update-EmbIndex([scriptblock]$status) {
    $stored = Read-EmbIndex
    $out = @{}; $dirty = $false
    foreach ($f in (Get-Notes)) {
        $key = $f.FullName; $mt = $f.LastWriteTime.ToString('o')
        if ($stored[$key] -and $stored[$key].mtime -eq $mt) { $out[$key] = $stored[$key]; continue }
        if ($status) { & $status "einbetten: $($f.BaseName)" }
        $txt = (Get-Content $f.FullName -Raw -Encoding utf8)
        if ($txt.Length -gt 2000) { $txt = $txt.Substring(0, 2000) }
        $v = Get-Embedding "$($f.BaseName)`n$txt"
        if (-not $v) { return $null }
        $out[$key] = @{ mtime = $mt; vec = $v }
        $dirty = $true
    }
    if ($dirty -or ($stored.Count -ne $out.Count)) { $out | ConvertTo-Json -Depth 4 -Compress | Set-Content $EmbIndexFile -Encoding utf8 }
    $out
}

function Get-Cosine($a, $b) {
    $dot = 0.0; $na = 0.0; $nb = 0.0
    for ($i = 0; $i -lt $a.Count; $i++) {
        $dot += [double]$a[$i] * [double]$b[$i]; $na += [double]$a[$i] * [double]$a[$i]; $nb += [double]$b[$i] * [double]$b[$i]
    }
    if ($na -eq 0 -or $nb -eq 0) { return 0 }
    $dot / ([math]::Sqrt($na) * [math]::Sqrt($nb))
}

# ============================================================ browser-landkarte (-Html)

function Write-VaultHtml {
    $idx = Get-LinkIndex
    $nodes = @()
    foreach ($key in $idx.Keys) {
        $f = $idx[$key].file
        $lines = @(Get-Content $f.FullName -Encoding utf8)
        $nodes += [pscustomobject]@{
            id = $key; name = $f.BaseName; text = ($lines -join "`n")
            out = @($idx[$key].out | Select-Object -Unique); tags = (Get-NoteTags $lines)
            date = $f.LastWriteTime.ToString('dd.MM.yyyy'); dir = (Split-Path (Split-Path $f.FullName -Parent) -Leaf)
        }
    }
    $json = ($nodes | ConvertTo-Json -Depth 4 -Compress) -replace '</script', '<\/script'
    $tpl = Get-Content (Join-Path $CoplandDir 'copland-vault-graph.html') -Raw -Encoding utf8
    $outF = Join-Path $VaultDir '_graph.html'
    $tpl.Replace('/*__DATA__*/[]', $json).Replace('__STAND__', ($script:Cur.label.ToLower() + ' | ' + (Get-Date -Format 'dd.MM.yyyy HH:mm'))) | Set-Content $outF -Encoding utf8
    $outF
}

if ($Html) {
    $v = Resolve-Vault $Bereich
    if (-not $v) { $v = Resolve-Vault 'a' }
    Set-Vault $v
    Write-Output (Write-VaultHtml); exit
}

# ============================================================ eingabe: tastatur + maus

$MouseOk = $false
if ($IsWin) {
    try {
        if (-not ('CopCon' -as [type])) {
            Add-Type -TypeDefinition @'
using System; using System.Runtime.InteropServices;
public static class CopCon {
  [StructLayout(LayoutKind.Sequential)] public struct COORD { public short X; public short Y; }
  [StructLayout(LayoutKind.Explicit)] public struct KEY_EVENT {
    [FieldOffset(0)] public int bKeyDown; [FieldOffset(4)] public ushort wRepeatCount;
    [FieldOffset(6)] public ushort wVirtualKeyCode; [FieldOffset(8)] public ushort wVirtualScanCode;
    [FieldOffset(10)] public char UnicodeChar; [FieldOffset(12)] public uint dwControlKeyState; }
  [StructLayout(LayoutKind.Sequential)] public struct MOUSE_EVENT { public COORD pos; public uint btn; public uint ctrl; public uint flags; }
  [StructLayout(LayoutKind.Explicit)] public struct INPUT_RECORD {
    [FieldOffset(0)] public ushort EventType; [FieldOffset(4)] public KEY_EVENT Key; [FieldOffset(4)] public MOUSE_EVENT Mouse; }
  [DllImport("kernel32.dll")] public static extern IntPtr GetStdHandle(int n);
  [DllImport("kernel32.dll")] public static extern bool GetConsoleMode(IntPtr h, out uint m);
  [DllImport("kernel32.dll")] public static extern bool SetConsoleMode(IntPtr h, uint m);
  [DllImport("kernel32.dll", CharSet=CharSet.Unicode)] public static extern bool ReadConsoleInput(IntPtr h, [Out] INPUT_RECORD[] buf, uint len, out uint read);
  [DllImport("kernel32.dll")] public static extern bool GetNumberOfConsoleInputEvents(IntPtr h, out uint n);
}
'@
        }
        $script:InH = [CopCon]::GetStdHandle(-10)
        $script:OldMode = [uint32]0
        [void][CopCon]::GetConsoleMode($script:InH, [ref]$script:OldMode)
        # maus an, quick-edit aus (sonst faengt die konsole klicks als markierung ab)
        $newMode = (($script:OldMode -bor 0x10 -bor 0x80) -band (-bnot 0x40))
        $MouseOk = [CopCon]::SetConsoleMode($script:InH, [uint32]$newMode)
    } catch { $MouseOk = $false }
}

# liefert @{ type='key'|'mouse'; key=vk; ch=char; ctrl=bool; x; y; btn='left'|'wheel'; delta }
# --- digital rain unten rechts in der notizspalte (nur wenn dort platz ist) ---
$RainW = 30; $RainH = 8
$RainChars = [char[]]'abcdefghikmnopqrstuvwxyz0123456789:.*+-='
$RainDrops = New-Object System.Collections.ArrayList
$RainTick = 0
function Step-VaultRain {
    $Geo = $script:Geo
    if (-not $Geo) { return }
    $x0 = $Geo.ctxX - 2 - $RainW
    $y0 = $Geo.Hgt - 2 - $RainH
    if ($x0 -lt $Geo.noteX + 40 -or $y0 -le $script:NoteBottomRow + 1) { return }   # kein freier platz
    $script:RainTick++
    if ($script:RainDrops.Count -lt 6 -and (Get-Random -Maximum 100) -lt 30) {
        [void]$script:RainDrops.Add(@{ x = Get-Random -Maximum $RainW; y = 0; len = 3 + (Get-Random -Maximum 4); slow = ((Get-Random -Maximum 2) -eq 0); chars = New-Object System.Collections.ArrayList })
    }
    $grid = @{}; $dead = @()
    foreach ($d in $script:RainDrops) {
        if (-not ($d.slow -and ($script:RainTick % 2))) {
            $d.chars.Insert(0, $script:RainChars[(Get-Random -Maximum $script:RainChars.Count)])
            while ($d.chars.Count -gt $d.len) { $d.chars.RemoveAt($d.chars.Count - 1) }
            $d.y++
        }
        for ($ci = 0; $ci -lt $d.chars.Count; $ci++) {
            $yy = $d.y - 1 - $ci
            if ($yy -ge 0 -and $yy -lt $RainH) { $grid["$($d.x),$yy"] = @($d.chars[$ci], ($ci -eq 0)) }
        }
        if ($d.y - $d.len -gt $RainH) { $dead += $d }
    }
    foreach ($d in $dead) { $script:RainDrops.Remove($d) }
    $out = "$E[s"
    for ($yy = 0; $yy -lt $RainH; $yy++) {
        $line = ''
        for ($xx = 0; $xx -lt $RainW; $xx++) {
            $c = $grid["$xx,$yy"]
            if ($c) { $line += if ($c[1]) { "$AC$($c[0])$DIM" } else { "$($c[0])" } } else { $line += ' ' }
        }
        $out += "$E[$($y0 + $yy);$($x0)H$DIM$line$R"
    }
    Write-Host -NoNewline "$out$E[u"
}

function Read-Input {
    if ($MouseOk) {
        $buf = New-Object 'CopCon+INPUT_RECORD[]' 1
        $n = [uint32]0
        while ($true) {
            # warten mit regen: nur lesen, wenn events anliegen
            $pending = [uint32]0
            [void][CopCon]::GetNumberOfConsoleInputEvents($script:InH, [ref]$pending)
            if ($pending -eq 0) { Step-VaultRain; Start-Sleep -Milliseconds 130; continue }
            if (-not [CopCon]::ReadConsoleInput($script:InH, $buf, 1, [ref]$n) -or $n -eq 0) { continue }
            $rec = $buf[0]
            if ($rec.EventType -eq 1) {
                if ($rec.Key.bKeyDown -eq 0) { continue }
                $vk = $rec.Key.wVirtualKeyCode
                if ($vk -in 16, 17, 18, 20, 91) { continue }   # shift/ctrl/alt/caps/win allein
                return @{ type = 'key'; key = $vk; ch = $rec.Key.UnicodeChar; ctrl = (($rec.Key.dwControlKeyState -band 0xC) -ne 0) }
            }
            if ($rec.EventType -eq 2) {
                $m = $rec.Mouse
                if ($m.flags -eq 4) {
                    $delta = [int16](($m.btn -shr 16) -band 0xFFFF)
                    return @{ type = 'mouse'; btn = 'wheel'; delta = $delta; x = $m.pos.X; y = $m.pos.Y }
                }
                if ($m.flags -eq 0 -and ($m.btn -band 1)) { return @{ type = 'mouse'; btn = 'left'; x = $m.pos.X; y = $m.pos.Y } }
                continue
            }
        }
    }
    $k = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
    @{ type = 'key'; key = $k.VirtualKeyCode; ch = $k.Character; ctrl = (($k.ControlKeyState -band 0xC) -ne 0) }
}

# ============================================================ darstellung

function Wrap-Text([string]$s, [int]$w) {
    if ($w -lt 8) { return , @($s) }
    $out = @()
    foreach ($para in ($s -split "`n")) {
        $line = ''
        foreach ($word in ($para -split ' ')) {
            if (($line + ' ' + $word).Trim().Length -gt $w -and $line) { $out += $line; $line = $word }
            else { $line = ($line + ' ' + $word).Trim() }
            while ($line.Length -gt $w) { $out += $line.Substring(0, $w); $line = $line.Substring($w) }
        }
        $out += $line
    }
    , @($out)
}

function Cut([string]$s, [int]$w) { if ($s.Length -gt $w) { $s.Substring(0, [math]::Max(0, $w - 1)) + '~' } else { $s } }
function Pad([string]$s, [int]$w) { (Cut $s $w).PadRight($w) }

# markdown-zeile faerben (nach dem umbruch): ueberschrift akzent, [[links]] akzent, code gedimmt
function Color-Line([string]$ln, [bool]$code, [bool]$meta = $false) {
    if ($code -or $ln -match '^```') { return "$DIM$ln$R" }
    if ($ln -match '^#') { return "$AC$($ln -replace '^#+\s*', '')$R" }
    if ($ln -match '^---\s*$') { return "$DIM$('.' * $ln.Length)$R" }
    $base = if ($meta) { $DIM } else { $FG }
    $t = $ln
    # listenpunkt: strich gedimmt, text normal
    if ($t -match '^(\s*)- (.*)$') { $t = $Matches[1] + $DIM + '- ' + $base + $Matches[2] }
    # [[links]] akzent + unterstrichen, #tags gedimmt
    $t = $t -replace '\[\[([^\]]+)\]\]', ($AC + "$E[4m" + '[[$1]]' + "$E[24m" + $base)
    $t = $t -replace '(?<=^|\s)(#[a-z0-9_\-/]+)', ($DIM + '$1' + $base)
    "$base$t$R"
}

# ============================================================ workspace-zustand

$S = @{
    filter = ''; semantic = $false; items = @(); sel = 0; top = 0
    focus = 'list'; note = $null; noteLines = @(); noteScroll = 0; noteLinkRows = @{}
    ctx = @(); ctxSel = 0; status = ''; all = @(); linkIdx = $null; emb = $null; showCtx = $false
}

function Refresh-Data {
    $S.all = Get-Notes
    $S.linkIdx = Get-LinkIndex
    $S.emb = Read-EmbIndex
    Apply-Filter
}

function Apply-Filter {
    $q = $S.filter
    if (-not $q) { $S.items = $S.all }
    elseif ($S.semantic -and $S.emb.Count) {
        $qv = Get-Embedding $q
        if ($qv) {
            $scored = foreach ($f in $S.all) { if ($S.emb[$f.FullName]) { [pscustomobject]@{ f = $f; sc = Get-Cosine $qv $S.emb[$f.FullName].vec } } }
            $S.items = @($scored | Sort-Object sc -Descending | Select-Object -First 30 | ForEach-Object { $_.f })
        } else { $S.status = 'ollama nicht erreichbar -- textfilter'; $S.items = @($S.all | Where-Object { $_.BaseName -match [regex]::Escape($q) }) }
    } else {
        $byName = @($S.all | Where-Object { $_.BaseName -match [regex]::Escape($q) })
        $byText = @($S.all | Where-Object { ($byName -notcontains $_) -and (Select-String -Path $_.FullName -Pattern ([regex]::Escape($q)) -Quiet) })
        $S.items = @($byName) + @($byText)
    }
    if ($S.sel -ge $S.items.Count) { $S.sel = [math]::Max(0, $S.items.Count - 1) }
    $S.top = 0
    Load-Note
}

function Load-Note {
    if (-not $S.items.Count) { $S.note = $null; $S.noteLines = @(); $S.ctx = @(); return }
    $f = $S.items[$S.sel]
    if ($S.note -and $S.note.FullName -eq $f.FullName) { return }
    $S.note = $f
    $S.noteLines = @(Get-Content $f.FullName -Encoding utf8)
    $S.noteScroll = 0
    $S.ctxSel = 0
    # kontext: eingehend, ausgehend, aehnlich, tags
    $me = $f.BaseName.ToLower()
    $node = $S.linkIdx[$me]
    # kontext als mini-graph: eingehend oben, knoten in der mitte, ausgehend/aehnlich/tags unten
    $ctx = @()
    $ins = if ($node) { @($node.in | Select-Object -Unique) } else { @() }
    foreach ($n in $ins) { $ctx += @{ label = $n; target = $n; pre = '<- ' } }
    if ($ins.Count) { $ctx += @{ dim = '     |' } }
    $ctx += @{ node = $f.BaseName }
    $outs = @(Get-WikiLinks $S.noteLines)
    if ($outs.Count) { $ctx += @{ dim = '     |' } }
    foreach ($n in $outs) {
        $mark = ''
        if (-not $S.linkIdx.ContainsKey($n.ToLower())) { $rn = Resolve-Note $n; $mark = if ($rn -and $rn.vault) { " ($($rn.vault.id))" } else { ' (neu)' } }
        $ctx += @{ label = "$n$mark"; target = $n; pre = '-> ' }
    }
    if ($S.emb.Count -and $S.emb[$f.FullName]) {
        $mv = $S.emb[$f.FullName].vec
        $sim = foreach ($key in $S.emb.Keys) {
            if ($key -ne $f.FullName -and (Test-Path $key)) { [pscustomobject]@{ n = [IO.Path]::GetFileNameWithoutExtension($key); sc = Get-Cosine $mv $S.emb[$key].vec } }
        }
        $top = @($sim | Sort-Object sc -Descending | Select-Object -First 4)
        if ($top.Count) { $ctx += @{ dim = '' } }
        foreach ($sm in $top) { $ctx += @{ label = "$($sm.n)"; pct = "$([math]::Round($sm.sc * 100))%"; target = $sm.n; pre = '~  '; sim = $true } }
    }
    $tags = Get-NoteTags $S.noteLines
    if ($tags.Count) { $ctx += @{ dim = '' }; $ctx += @{ dim = ('#  ' + (($tags | ForEach-Object { "#$_" }) -join ' ')) } }
    $S.ctx = $ctx
}

function Get-Geo {
    $win = $Host.UI.RawUI.WindowSize
    $W = $win.Width; $H = $win.Height
    $Lw = [math]::Min(36, [math]::Max(18, [int]($W * 0.24)))
    $Cw = if ($S.showCtx) { [math]::Min(34, [math]::Max(20, [int]($W * 0.26))) } else { 0 }
    $ctxX = if ($S.showCtx) { $W - $Cw - 1 } else { $W + 2 }
    $script:Geo = @{ W = $W; Hgt = $H; Lw = $Lw; Cw = $Cw; Nw = ($W - $Lw - $Cw - 9); top = 3; h = ($H - 5); noteX = $Lw + 5; ctxX = $ctxX }
}

function Draw {
    $Geo = $script:Geo
    $W = $Geo.W; $H = $Geo.Hgt; $Lw = $Geo.Lw; $Cw = $Geo.Cw; $bodyTop = $Geo.top; $bodyH = $Geo.h
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.Append("$E[H")
    $script:RainDrops.Clear()
    # kopf
    $mode = if ($S.semantic) { 'semantik' } else { 'filter' }
    $head = "$AC   VAULT$R$FG $($script:Cur.label.ToLower())$R$DIM  $($S.all.Count) notizen | $($S.items.Count) gezeigt$R"
    $prompt = "$DIM$mode > $R$FG$($S.filter)$AC_$R"
    [void]$sb.Append("$E[1;1H$E[K$head$E[1;$($W - 40)H$prompt")
    [void]$sb.Append("$E[2;1H$E[K$DIM   $('.' * ($W - 6))$R")
    # spaltentitel: gedimmt, die aktive spalte im akzent
    $fl = if ($S.focus -eq 'list') { $AC } else { $DIM }
    $fn = if ($S.focus -eq 'note') { $AC } else { $DIM }
    $fc = if ($S.focus -eq 'ctx') { $AC } else { $DIM }
    [void]$sb.Append("$E[3;1H$E[K$fl   liste$R$E[3;$($Geo.noteX + 1)H$fn notiz$R")
    if ($S.showCtx) { [void]$sb.Append("$E[3;$($Geo.ctxX + 1)H$fc kontext$R") }
    # liste (scrollfenster)
    if ($S.sel -lt $S.top) { $S.top = $S.sel }
    if ($S.sel -ge $S.top + $bodyH - 1) { $S.top = $S.sel - $bodyH + 2 }
    $script:NoteLinkRows = @{}
    # fokus-dimmen: liste und kontext werden gedimmt, wenn sie nicht fokussiert sind; die notiz bleibt lesbar
    $lFg = if ($S.focus -eq 'list') { $FG } else { $DIM }
    $cFg = if ($S.focus -eq 'ctx') { $FG } else { $DIM }
    # trennstriche nur so weit, wie inhalt steht
    $rowsList = [math]::Min($S.items.Count - $S.top, $bodyH - 1)
    $rowsNote = [math]::Min($script:NoteView.Count - $S.noteScroll, $bodyH - 1)
    $rowsCtx = [math]::Min($S.ctx.Count, $bodyH - 1)
    $sepL = [math]::Max($rowsList, $rowsNote); $sepR = [math]::Max($rowsNote, $rowsCtx)
    $script:NoteBottomRow = $bodyTop + [math]::Max(1, $rowsNote)
    for ($ri = 0; $ri -lt $bodyH - 1; $ri++) {
        $y = $bodyTop + 1 + $ri
        $i = $S.top + $ri
        $cell = ' ' * ($Lw + 2)
        if ($i -lt $S.items.Count) {
            $f = $S.items[$i]
            # mini-pegel: anzahl links als punkte (0-3)
            $nd = $S.linkIdx[$f.BaseName.ToLower()]
            $deg = if ($nd) { @($nd.in).Count + @($nd.out).Count } else { 0 }
            $peg = ('.' * [math]::Min(3, $deg)).PadLeft(3)
            $nm = Pad $f.BaseName ($Lw - 5)
            $cell = if ($i -eq $S.sel) { "$AC > $nm$R$DIM$peg$R" } else { "$lFg   $nm$R$DIM$peg$R" }
        }
        $sl = if ($ri -lt $sepL) { "$DIM|$R" } else { ' ' }
        [void]$sb.Append("$E[$y;1H$E[K$cell$sl")
        # notiz
        $li = $S.noteScroll + $ri
        if ($li -lt $script:NoteView.Count) {
            $nl = $script:NoteView[$li]
            [void]$sb.Append("$E[$y;$($Geo.noteX)H$(Color-Line $nl.t $nl.code ([bool]$nl.meta))")
            if ($nl.t -match '\[\[') { $script:NoteLinkRows[$y] = $nl.t }
        }
        # kontext (mini-graph) -- nur wenn per tab geoeffnet
        if (-not $S.showCtx) { continue }
        $sr = if ($ri -lt $sepR) { "$DIM|$R" } else { ' ' }
        [void]$sb.Append("$E[$y;$($Geo.ctxX - 1)H$sr")
        if ($ri -lt $S.ctx.Count) {
            $c = $S.ctx[$ri]
            $txt = if ($c.node) { "$AC   [$(Cut $c.node ($Cw - 6))]$R" }
                   elseif ($null -ne $c.dim) { "$DIM$(Cut $c.dim ($Cw - 2))$R" }
                   else {
                       $lab = Pad $c.label ($Cw - 8)
                       $pct = if ($c.pct) { "$DIM$($c.pct)$R" } else { '' }
                       $col = if ($c.sim) { $DIM } else { $cFg }
                       if ($S.focus -eq 'ctx' -and $ri -eq $S.ctxSel) { "$AC$($c.pre)$lab$R$pct" } else { "$col$($c.pre)$lab$R$pct" }
                   }
            [void]$sb.Append("$E[$y;$($Geo.ctxX + 1)H$txt")
        }
    }
    # fuss
    $foot = "tippen=filtern  pfeile/maus=waehlen  tab=kontext  ^f=semantik  ^w=bereich  ^b=browser  ^e=editor  ^d=daily  ^n=neu  esc=zurueck"
    [void]$sb.Append("$E[$($H - 1);1H$E[K$DIM   $(Cut $foot ($W - 4))$R")
    $st = if ($S.status) { "$WARN   $(Cut $S.status ($W - 4))$R" } else { '' }
    [void]$sb.Append("$E[$H;1H$E[K$st")
    Write-Host -NoNewline $sb.ToString()
}

# notiz fuer die aktuelle breite umbrechen (cache je notiz+breite)
function Build-NoteView {
    $Nw = [math]::Min(72, $script:Geo.Nw)   # lesebreite: nicht breiter als ~72 zeichen
    $view = New-Object System.Collections.ArrayList
    if ($S.note) {
        [void]$view.Add(@{ t = "# $($S.note.BaseName)"; code = $false })
        [void]$view.Add(@{ t = ''; code = $false })
        $inCode = $false; $meta = @(); $lastBlank = $true
        foreach ($ln in $S.noteLines) {
            if ($ln -match '^```') { $inCode = -not $inCode; [void]$view.Add(@{ t = $ln; code = $true }); $lastBlank = $false; continue }
            # meta (verwandt/quelle/angelegt/reine tag-zeilen) wandert gedimmt ans ende
            if (-not $inCode -and ($ln -match '^(Verwandt|Quelle|Angelegt|Ergaenzt|Tags?)\s*:' -or $ln -match '^\s*(#[a-z0-9_\-/]+\s*)+$')) { $meta += $ln; continue }
            if (-not $ln.Trim()) { if ($lastBlank) { continue }; $lastBlank = $true; [void]$view.Add(@{ t = ''; code = $false }); continue }
            # titelzeile der datei (erste # ueberschrift) nicht doppelt zeigen
            if ($ln -match '^#\s' -and $view.Count -le 2) { continue }
            $lastBlank = $false
            foreach ($wl in (Wrap-Text $ln $Nw)) { [void]$view.Add(@{ t = $wl; code = $inCode }) }
        }
        if ($meta.Count) {
            if (-not $lastBlank) { [void]$view.Add(@{ t = ''; code = $false }) }
            [void]$view.Add(@{ t = ('.' * [math]::Min(24, $Nw)); code = $true })
            foreach ($ml in $meta) { foreach ($wl in (Wrap-Text $ml $Nw)) { [void]$view.Add(@{ t = $wl; code = $false; meta = $true }) } }
        }
        [void]$view.Add(@{ t = $S.note.LastWriteTime.ToString('dd.MM.yyyy HH:mm'); code = $false; meta = $true })
    }
    $script:NoteView = @($view)
}

# link aus einer notiz-zeile folgen: erste [[..]] auf der zeile
function Follow-Link([string]$name) {
    $t = Resolve-Note $name
    if ($t -and $t.vault) { Set-Vault $t.vault; Refresh-Data; $S.status = "bereich: $($t.vault.label.ToLower())" }
    if (-not $t) {
        $np = Join-Path $VaultDir "$($name.Trim()).md"
        @("# $($name.Trim())", '') | Set-Content $np -Encoding utf8
        $t = Get-Item $np
        $S.status = "angelegt: $($name.Trim())"
        Refresh-Data
    }
    Select-Note $t
}

function Select-Note($f) {
    # notiz in die liste holen (filter loeschen falls sie nicht drin ist) und anwaehlen
    $pos = -1
    for ($i = 0; $i -lt $S.items.Count; $i++) { if ($S.items[$i].FullName -eq $f.FullName) { $pos = $i; break } }
    if ($pos -lt 0) { $S.filter = ''; $S.semantic = $false; Apply-Filter; for ($i = 0; $i -lt $S.items.Count; $i++) { if ($S.items[$i].FullName -eq $f.FullName) { $pos = $i; break } } }
    if ($pos -ge 0) { $S.sel = $pos; $S.focus = 'list'; Load-Note }
}

function Show-FullScreen([string[]]$lines) {
    # einfacher vollbild-schirm (graph, link-ideen), beliebige taste/klick zurueck
    Clear-Host
    foreach ($ln in $lines) { Write-Host $ln }
    Write-Host ""
    Write-Host -NoNewline "$DIM   [taste] zurueck $R"
    [void](Read-Input)
    Clear-Host
}

function Show-Graph {
    if (-not $S.note) { return }
    $idx = $S.linkIdx; $me = $S.note.BaseName.ToLower(); $node = $idx[$me]
    $out = @('', "$AC   GRAPH$R$DIM  $($S.note.BaseName)$R", "$DIM   ---------------------------------------$R")
    if ($node.in.Count) { foreach ($src in ($node.in | Select-Object -Unique)) { $out += "$DIM   $src ->$R" } } else { $out += "$DIM   (keine eingehenden)$R" }
    $out += "$AC       [$($S.note.BaseName)]$R"
    if ($node.out.Count) {
        foreach ($dst in ($node.out | Select-Object -Unique)) {
            $out += "$FG           -> $dst$R"
            if ($idx.ContainsKey($dst)) { foreach ($d2 in ($idx[$dst].out | Select-Object -Unique -First 4)) { if ($d2 -ne $me) { $out += "$DIM                -> $d2$R" } } }
        }
    } else { $out += "$DIM           (keine ausgehenden)$R" }
    Show-FullScreen $out
}

function Show-LinkIdeas {
    Clear-Host
    Write-Host ""
    $emb = Update-EmbIndex { param($m) Write-Host "$DIM   $m$R" }
    if (-not $emb) { Show-FullScreen @('', "$WARN   ollama/$EmbModel nicht erreichbar (ollama pull $EmbModel)$R"); return }
    $S.emb = $emb
    $keys = @($emb.Keys | Where-Object { Test-Path $_ })
    $pairs = New-Object System.Collections.ArrayList
    for ($i = 0; $i -lt $keys.Count; $i++) {
        for ($j = $i + 1; $j -lt $keys.Count; $j++) {
            $la = [IO.Path]::GetFileNameWithoutExtension($keys[$i]).ToLower(); $lb = [IO.Path]::GetFileNameWithoutExtension($keys[$j]).ToLower()
            if ($S.linkIdx[$la] -and (($S.linkIdx[$la].out -contains $lb) -or ($S.linkIdx[$la].in -contains $lb))) { continue }
            $sc = Get-Cosine $emb[$keys[$i]].vec $emb[$keys[$j]].vec
            if ($sc -gt 0.55) { [void]$pairs.Add([pscustomobject]@{ a = $la; b = $lb; sc = $sc }) }
        }
    }
    $out = @('', "$AC   LINK-IDEEN$R$DIM  unverlinkte paare mit aehnlichkeit > 55%$R", "$DIM   ---------------------------------------$R")
    $top = @($pairs | Sort-Object sc -Descending | Select-Object -First 15)
    if (-not $top) { $out += "$DIM   (keine vorschlaege)$R" }
    foreach ($p in $top) { $out += "$FG   $($p.a)$R$DIM <-> $R$FG$($p.b)$R$DIM  $([math]::Round($p.sc * 100))%$R" }
    Show-FullScreen $out
}

function Read-Line-Bottom([string]$label) {
    $H = $Host.UI.RawUI.WindowSize.Height
    Write-Host -NoNewline "$E[$H;1H$E[K$AC   $label > $R"
    [Console]::CursorVisible = $true
    $v = Read-Host
    [Console]::CursorVisible = $false
    $v
}

# ============================================================ bereichswahl + hauptschleife

# chooser: welcher bereichs-vault? gibt vault-eintrag oder $null (zurueck)
function Choose-Vault {
    Clear-Host
    Write-Host ""
    Write-Host "$AC   VAULT$R$DIM  ein wissens-vault je lebensbereich$R"
    Write-Host "$DIM   ---------------------------------------$R"
    foreach ($v in $Vaults) {
        $d = Get-VaultDirOf $v
        $cnt = if (Test-Path $d) { @(Get-ChildItem $d -Recurse -File -Filter *.md | Where-Object { $_.Name -notmatch '^_' }).Count } else { 0 }
        $cs = if ($cnt) { "$cnt notizen" } else { 'leer' }
        Write-Host "$AC   [$($v.key)]$R$FG $($v.label.PadRight(9))$R$DIM $($v.dir.PadRight(14))$cs$R"
    }
    Write-Host ""
    Write-Host -NoNewline "$DIM   [z] zurueck $R"
    while ($true) {
        $ev = Read-Input
        if ($ev.type -ne 'key') { continue }
        $ch = "$($ev.ch)".ToLower()
        if ($ch -eq 'z' -or $ev.key -eq 27) { return $null }
        $v = Resolve-Vault $ch
        if ($v) { return $v }
    }
}

$Host.UI.RawUI.WindowTitle = 'vault'
Write-Host -NoNewline "$E[?1049h$E[?25l"   # alternativer schirm, cursor aus
try {
    $v0 = if ($Bereich) { Resolve-Vault $Bereich } else { Choose-Vault }
    if ($v0) {
    Set-Vault $v0
    Refresh-Data
    Clear-Host
    $quit = $false
    while (-not $quit) {
        Get-Geo
        Build-NoteView
        Draw
        $ev = Read-Input
        $S.status = ''
        $Geo = $script:Geo
        if ($ev.type -eq 'mouse') {
            $x = $ev.x; $y = $ev.y   # 0-basiert
            $inList = ($x -lt $Geo.Lw + 2); $inCtx = ($S.showCtx -and $x -ge $Geo.ctxX - 1); $inNote = (-not $inList -and -not $inCtx)
            if ($ev.btn -eq 'wheel') {
                $d = if ($ev.delta -gt 0) { -3 } else { 3 }
                if ($inList) { $S.sel = [math]::Max(0, [math]::Min($S.items.Count - 1, $S.sel + $d)); Load-Note }
                elseif ($inNote) { $S.noteScroll = [math]::Max(0, [math]::Min([math]::Max(0, $script:NoteView.Count - $Geo.h + 2), $S.noteScroll + $d)) }
                continue
            }
            $row = $y - ($Geo.top - 1)   # 0 = spaltentitel, 1.. = zeilen
            if ($row -lt 1) { continue }
            if ($inList) {
                $i = $S.top + $row - 1
                if ($i -lt $S.items.Count) { $S.sel = $i; $S.focus = 'list'; Load-Note }
            } elseif ($inCtx) {
                $ci = $row - 1
                if ($ci -lt $S.ctx.Count -and $S.ctx[$ci].target) { $S.focus = 'ctx'; $S.ctxSel = $ci; Follow-Link $S.ctx[$ci].target }
            } else {
                $ln = $script:NoteLinkRows[$y + 1]
                if ($ln -and $ln -match '\[\[([^\]\|#]+)') { Follow-Link $Matches[1] }
                else { $S.focus = 'note' }
            }
            continue
        }
        # --- tastatur ---
        $vk = $ev.key
        # ctrl erkennen: flag ODER steuerzeichen 1..26 (conpty liefert ctrl+b manchmal nur als 0x02)
        $code = if ("$($ev.ch)") { [int][char]"$($ev.ch)" } else { 0 }
        if (-not $ev.ctrl -and $code -ge 1 -and $code -le 26 -and $vk -notin 8, 9, 13, 27) { $ev.ctrl = $true; $vk = 64 + $code }
        if ($ev.ctrl) {
            switch ($vk) {
                70 { $S.semantic = -not $S.semantic; if ($S.semantic -and -not $S.emb.Count) { $S.emb = Update-EmbIndex $null; if (-not $S.emb) { $S.emb = @{}; $S.semantic = $false; $S.status = 'ollama nicht erreichbar' } }; Apply-Filter }   # ^f
                71 { Show-Graph }                                                                                        # ^g
                66 { $hf = Write-VaultHtml; Open-Item $hf; $S.status = "browser: $hf" }                                # ^b
                69 { if ($S.note) { Open-Item $S.note.FullName } }                                                       # ^e
                68 { $d = Get-DailyNote; Refresh-Data; Select-Note $d }                                                  # ^d
                78 { $nn = Read-Line-Bottom 'name'; $nf = New-Note $nn; if ($nf) { Refresh-Data; Select-Note $nf; Open-Item $nf.FullName } }   # ^n
                88 { Show-LinkIdeas }                                                                                    # ^x
                82 { Refresh-Data; $S.status = 'neu gelesen' }                                                           # ^r
                87 { $nv = Choose-Vault; Clear-Host; if ($nv) { Set-Vault $nv; $S.filter = ''; $S.note = $null; Refresh-Data } }   # ^w
            }
            continue
        }
        switch ($vk) {
            27 { if ($S.filter) { $S.filter = ''; Apply-Filter } else { $quit = $true } }                              # esc
            9  { $S.focus = switch ($S.focus) { 'list' { 'note' } 'note' { 'ctx' } default { 'list' } }
                 $S.showCtx = ($S.focus -eq 'ctx')
                 if ($S.focus -eq 'ctx') { $S.ctxSel = 0; for ($ci = 0; $ci -lt $S.ctx.Count; $ci++) { if ($S.ctx[$ci].target) { $S.ctxSel = $ci; break } } }
                 Clear-Host }   # tab
            38 { if ($S.focus -eq 'ctx') { do { $S.ctxSel = [math]::Max(0, $S.ctxSel - 1) } while ($S.ctxSel -gt 0 -and -not $S.ctx[$S.ctxSel].target) }
                 elseif ($S.focus -eq 'note') { $S.noteScroll = [math]::Max(0, $S.noteScroll - 1) }
                 else { $S.sel = [math]::Max(0, $S.sel - 1); Load-Note } }
            40 { if ($S.focus -eq 'ctx') { $n0 = $S.ctxSel; do { $S.ctxSel = [math]::Min($S.ctx.Count - 1, $S.ctxSel + 1) } while ($S.ctxSel -lt $S.ctx.Count - 1 -and -not $S.ctx[$S.ctxSel].target); if (-not $S.ctx[$S.ctxSel].target) { $S.ctxSel = $n0 } }
                 elseif ($S.focus -eq 'note') { $S.noteScroll = [math]::Min([math]::Max(0, $script:NoteView.Count - $Geo.h + 2), $S.noteScroll + 1) }
                 else { $S.sel = [math]::Min($S.items.Count - 1, $S.sel + 1); Load-Note } }
            33 { $S.noteScroll = [math]::Max(0, $S.noteScroll - ($Geo.h - 2)) }                                          # pgup
            34 { $S.noteScroll = [math]::Min([math]::Max(0, $script:NoteView.Count - $Geo.h + 2), $S.noteScroll + ($Geo.h - 2)) }
            13 { if ($S.focus -eq 'ctx') { $c = $S.ctx[$S.ctxSel]; if ($c.target) { Follow-Link $c.target } }
                 elseif ($S.focus -eq 'list') { $S.focus = 'note' }
                 else { $S.focus = 'list' } }
            8  { if ($S.filter.Length) { $S.filter = $S.filter.Substring(0, $S.filter.Length - 1); Apply-Filter } }     # backspace
            default {
                $ch = "$($ev.ch)"
                if ($ch -and [int][char]$ch -ge 32) { $S.filter += $ch; $S.focus = 'list'; Apply-Filter }
            }
        }
    }
    }
} finally {
    if ($MouseOk) { [void][CopCon]::SetConsoleMode($script:InH, $script:OldMode) }
    Write-Host -NoNewline "$E[?25h$E[?1049l"
}
