# COPLAND OS -- spotify-player (vollbild, [u] im launcher)
# steuert die spotify-desktop-app ueber die system-media-session: kein api-key noetig.
#   space = play/pause   n / pfeil-rechts = next   b / pfeil-links = prev
#   hoch/runter = bibliothek waehlen   enter = abspielen   r = bibliothek neu laden   q = ende
# bibliothek: cache <CacheDir>/copland-spotify-bib.json (claude befuellt sie per mcp:
#   "aktualisiere meine spotify-bibliothek"). ohne api oeffnet enter die app am ziel.
# optional web-api (echtes "spiele album X" vom terminal): datei ~/.claude/cache/spotify-client-id.txt
# mit der client-id einer eigenen spotify-app (redirect http://127.0.0.1:8888/callback);
# einmal browser-login, danach automatisch -- fern-abspielen braucht premium.

$ErrorActionPreference = 'SilentlyContinue'
. (Join-Path $PSScriptRoot 'copland-shared.ps1')

$BibFile = Join-Path $CacheDir 'copland-spotify-bib.json'
$CidFile = Join-Path $ClaudeHome 'cache/spotify-client-id.txt'
$TokFile = Join-Path $ClaudeHome 'cache/spotify-token.json'

# --- optionale web-api (pkce) -----------------------------------------------
function Get-SpApiToken {
    if (-not (Test-Path $CidFile)) { return $null }
    $cid = (Get-Content $CidFile -TotalCount 1).Trim()
    if (-not $cid) { return $null }
    $tok = $null
    if (Test-Path $TokFile) { $tok = Get-Content $TokFile -Raw | ConvertFrom-Json }
    if ($tok -and $tok.exp -gt ([DateTimeOffset]::Now.ToUnixTimeSeconds() + 60)) { return $tok.access }
    if ($tok -and $tok.refresh) {
        try {
            $rsp = Invoke-RestMethod -Method Post 'https://accounts.spotify.com/api/token' -Body @{
                grant_type = 'refresh_token'; refresh_token = $tok.refresh; client_id = $cid }
            $newRefresh = if ($rsp.refresh_token) { $rsp.refresh_token } else { $tok.refresh }
            @{ access = $rsp.access_token; refresh = $newRefresh
               exp = [DateTimeOffset]::Now.ToUnixTimeSeconds() + [int]$rsp.expires_in } |
                ConvertTo-Json -Compress | Set-Content $TokFile -Encoding utf8
            return $rsp.access_token
        } catch { }
    }
    # erster login: pkce + localhost-callback
    $chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789'
    $verifier = -join (1..64 | ForEach-Object { $chars[(Get-Random -Maximum 62)] })
    $sha = [System.Security.Cryptography.SHA256]::Create()
    $challenge = [Convert]::ToBase64String($sha.ComputeHash([Text.Encoding]::ASCII.GetBytes($verifier))).TrimEnd('=').Replace('+','-').Replace('/','_')
    $redirect = 'http://127.0.0.1:8888/callback'
    $scopes = 'user-modify-playback-state user-read-playback-state playlist-read-private user-library-read'
    $authUrl = 'https://accounts.spotify.com/authorize?response_type=code&client_id=' + $cid +
           '&redirect_uri=' + [uri]::EscapeDataString($redirect) +
           '&scope=' + [uri]::EscapeDataString($scopes) +
           '&code_challenge_method=S256&code_challenge=' + $challenge
    $listener = New-Object System.Net.HttpListener
    $listener.Prefixes.Add('http://127.0.0.1:8888/')
    try { $listener.Start() } catch { return $null }
    Open-Item $authUrl
    Write-Host "$DIM  browser-login laeuft (spotify) ...$R"
    $ctx = $listener.GetContext()
    $code = $ctx.Request.QueryString['code']
    $msg = [Text.Encoding]::UTF8.GetBytes('<html><body style="background:#000;color:#8CABC6;font-family:monospace"><p>copland: verbunden. fenster schliessen.</p></body></html>')
    $ctx.Response.OutputStream.Write($msg, 0, $msg.Length); $ctx.Response.Close(); $listener.Stop()
    if (-not $code) { return $null }
    try {
        $rsp = Invoke-RestMethod -Method Post 'https://accounts.spotify.com/api/token' -Body @{
            grant_type = 'authorization_code'; code = $code; redirect_uri = $redirect
            client_id = $cid; code_verifier = $verifier }
        @{ access = $rsp.access_token; refresh = $rsp.refresh_token
           exp = [DateTimeOffset]::Now.ToUnixTimeSeconds() + [int]$rsp.expires_in } |
            ConvertTo-Json -Compress | Set-Content $TokFile -Encoding utf8
        return $rsp.access_token
    } catch { return $null }
}

function Get-SpLibrary([switch]$Force) {
    # web-api, wenn eingerichtet: eigene playlists + gespeicherte alben, cache 24h
    $apiTok = Get-SpApiToken
    if ($apiTok) {
        $fresh = (Test-Path $BibFile) -and (((Get-Date) - (Get-Item $BibFile).LastWriteTime).TotalHours -lt 24)
        if (-not $fresh -or $Force) {
            $items = @()
            try {
                $hdr = @{ Authorization = "Bearer $apiTok" }
                $pl = Invoke-RestMethod 'https://api.spotify.com/v1/me/playlists?limit=50' -Headers $hdr
                foreach ($it in $pl.items) { $items += @{ name = "$($it.name)"; uri = "$($it.uri)"; typ = 'playlist' } }
                $al = Invoke-RestMethod 'https://api.spotify.com/v1/me/albums?limit=50' -Headers $hdr
                foreach ($it in $al.items) { $items += @{ name = "$($it.album.artists[0].name) -- $($it.album.name)"; uri = "$($it.album.uri)"; typ = 'album' } }
            } catch { }
            if ($items.Count) { ConvertTo-Json @($items) -Depth 4 -Compress | Set-Content $BibFile -Encoding utf8 }
        }
    }
    # cache-datei (auch von claude/mcp befuellbar)
    if (Test-Path $BibFile) {
        $raw = Get-Content $BibFile -Raw | ConvertFrom-Json
        return @($raw | ForEach-Object { $_ })
    }
    @()
}

function Play-SpItem($item) {
    $apiTok = Get-SpApiToken
    if ($apiTok) {
        try {
            $hdr = @{ Authorization = "Bearer $apiTok"; 'Content-Type' = 'application/json' }
            $body = @{ context_uri = "$($item.uri)" } | ConvertTo-Json -Compress
            Invoke-RestMethod -Method Put 'https://api.spotify.com/v1/me/player/play' -Headers $hdr -Body $body | Out-Null
            return 'spielt'
        } catch {
            # kein aktives geraet -> geraet dieses rechners suchen und dort starten
            try {
                $dev = (Invoke-RestMethod 'https://api.spotify.com/v1/me/player/devices' -Headers @{ Authorization = "Bearer $apiTok" }).devices |
                    Where-Object { $_.type -eq 'Computer' } | Select-Object -First 1
                if ($dev) {
                    Invoke-RestMethod -Method Put ('https://api.spotify.com/v1/me/player/play?device_id=' + $dev.id) `
                        -Headers @{ Authorization = "Bearer $apiTok"; 'Content-Type' = 'application/json' } `
                        -Body (@{ context_uri = "$($item.uri)" } | ConvertTo-Json -Compress) | Out-Null
                    return 'spielt'
                }
            } catch { }
        }
    }
    # fallback ohne api: in der app oeffnen (dort play druecken)
    Open-Item "$($item.uri)"
    'in spotify geoeffnet -- dort play druecken (api einrichten = direkt abspielen, siehe kopf)'
}

# --- visualizer (braille-saeulen, 6 zeilen = 24 stufen) ----------------------
function Draw-Viz([int[]]$vh, [int]$vRow, [int]$xOff, [bool]$playing) {
    $rows = 6
    for ($vr = 0; $vr -lt $rows; $vr++) {
        $sb = New-Object System.Text.StringBuilder
        for ($vc = 0; $vc -lt $vh.Count; $vc++) {
            $f = [math]::Min(4, [math]::Max(0, $vh[$vc] - ($rows - 1 - $vr) * 4))
            $bits = 0
            if ($f -ge 1) { $bits = $bits -bor 0xC0 }
            if ($f -ge 2) { $bits = $bits -bor 0x24 }
            if ($f -ge 3) { $bits = $bits -bor 0x12 }
            if ($f -ge 4) { $bits = $bits -bor 0x09 }
            [void]$sb.Append([char](0x2800 + $bits))
        }
        try { [Console]::SetCursorPosition($xOff, $vRow + $vr) } catch { return }
        $cl = if ($playing) { $AC } else { $DIM }
        Write-Host "$cl$($sb.ToString())$R" -NoNewline
    }
}

function CutS([string]$s, [int]$mx) { if ($s.Length -gt $mx) { $s.Substring(0, $mx - 1) + '~' } else { $s } }

# --- ui ----------------------------------------------------------------------
$Host.UI.RawUI.WindowTitle = 'spotify'
[Console]::CursorVisible = $false
$bib = @(Get-SpLibrary)
$sel = 0
$note = ''
$apiOn = [bool](Test-Path $CidFile)

while ($true) {
    Clear-Host
    $winW = $Host.UI.RawUI.WindowSize.Width
    $winH = $Host.UI.RawUI.WindowSize.Height
    $W = $winW - 6

    $sp = Get-SpotifyNow
    Write-Host ""
    $tag = if ($sp -and $sp.playing) { "$AC>$R" } elseif ($sp) { "$DIM=$R" } else { "$DIM.$R" }
    $apiTag = if ($apiOn) { "$DIM api$R" } else { '' }
    Write-Host "$DIM   SPOTIFY$R  $tag  $apiTag"
    Write-Host ""
    if ($sp -and "$($sp.title)") {
        Write-Host "$FG   $(CutS $sp.title $W)$R"
        Write-Host "$AC   $(CutS $sp.artist $W)$R"
        if ("$($sp.album)" -and $sp.album -ne $sp.title) { Write-Host "$DIM   $(CutS $sp.album $W)$R" } else { Write-Host "" }
    } else {
        Write-Host "$DIM   nichts an -- spotify-app starten oder [enter] auf einen eintrag$R"
        Write-Host ""
        Write-Host ""
    }
    Write-Host ""
    $progRow = [Console]::CursorTop
    Write-Host ""
    Write-Host ""

    # bibliothek
    Write-Host "$DIM   bibliothek$R$(if (-not $bib.Count) { "$DIM   (leer -- claude sagen: aktualisiere meine spotify-bibliothek)$R" })"
    $listRow = [Console]::CursorTop
    $maxList = [math]::Max(0, ($winH - 11) - $listRow)
    $shown = [math]::Min($bib.Count, $maxList)
    $off = 0
    if ($shown -gt 0 -and $sel -ge $shown) { $off = [math]::Min($sel - $shown + 1, $bib.Count - $shown) }
    for ($li = 0; $li -lt $shown; $li++) {
        $it = $bib[$off + $li]
        $mark = if (($off + $li) -eq $sel) { "$AC > $R" } else { '   ' }
        $nm = CutS "$($it.name)" ($W - 12)
        Write-Host "$mark$FG$nm$R$DIM  $($it.typ)$R"
    }
    Write-Host ""
    if ($note) { Write-Host "$DIM   $(CutS $note $W)$R" }

    # fusszeile + visualizer unten
    $vizRow = $winH - 9
    $navRow = $winH - 2
    try { [Console]::SetCursorPosition(0, $navRow) } catch { }
    Write-Host "$DIM   [space] pause   [n/b] next/prev   [enter] abspielen   [r] neu laden   [q] ende$R" -NoNewline

    $vh = New-Object 'int[]' ([math]::Max(10, $winW - 8))
    $vT0 = Get-Date; $lastFetch = Get-Date; $spTitle = "$(if ($sp) { $sp.title })"
    $redraw = $false
    while (-not $redraw -and ((Get-Date) - $vT0).TotalSeconds -lt 45) {
        if ([Console]::KeyAvailable) {
            $ki = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
            $ch = "$($ki.Character)"; $vk = $ki.VirtualKeyCode
            if ($ch -match '^[qQ]$') { [Console]::CursorVisible = $true; exit }
            elseif ($ch -eq ' ') { $null = Invoke-SpotifyCtl 'toggle'; Start-Sleep -Milliseconds 300; $redraw = $true }
            elseif ($ch -match '^[nN]$' -or $vk -eq 39) { $null = Invoke-SpotifyCtl 'next'; Start-Sleep -Milliseconds 500; $redraw = $true }
            elseif ($ch -match '^[bB]$' -or $vk -eq 37) { $null = Invoke-SpotifyCtl 'prev'; Start-Sleep -Milliseconds 500; $redraw = $true }
            elseif ($vk -eq 38) { if ($sel -gt 0) { $sel-- }; $redraw = $true }
            elseif ($vk -eq 40) { if ($sel -lt $bib.Count - 1) { $sel++ }; $redraw = $true }
            elseif ($vk -eq 13 -and $bib.Count) { $note = Play-SpItem $bib[$sel]; Start-Sleep -Milliseconds 800; $redraw = $true }
            elseif ($ch -match '^[rR]$') { $bib = @(Get-SpLibrary -Force); $sel = 0; $note = "bibliothek: $($bib.Count) eintraege"; $redraw = $true }
            continue
        }
        # pegel: kicks + abklingen; pausiert = flache linie
        if ($sp -and $sp.playing) {
            for ($vi = 0; $vi -lt $vh.Count; $vi++) {
                $vh[$vi] = [math]::Max(0, $vh[$vi] - (Get-Random -Minimum 1 -Maximum 5))
                if ((Get-Random -Maximum 100) -lt 20) { $vh[$vi] = [math]::Max($vh[$vi], (Get-Random -Minimum 4 -Maximum 25)) }
            }
            for ($vi = 1; $vi -lt $vh.Count - 1; $vi++) { $vh[$vi] = [int](($vh[$vi - 1] + 2 * $vh[$vi] + $vh[$vi + 1]) / 4) }
        } else {
            for ($vi = 0; $vi -lt $vh.Count; $vi++) { $vh[$vi] = if ($vi % 9 -eq 4) { 1 } else { 0 } }
        }
        Draw-Viz $vh $vizRow 3 ($sp -and $sp.playing)
        # fortschritt
        if ($sp -and $sp.len -gt 0) {
            $posNow = [math]::Min($sp.len, $sp.pos + [int]((Get-Date) - $lastFetch).TotalSeconds * $(if ($sp.playing) { 1 } else { 0 }))
            $bw = $winW - 20
            $fill = [int]($posNow / $sp.len * $bw)
            $bar = ('=' * $fill).PadRight($bw, '.')
            $tS = '{0}:{1:d2}' -f [int][math]::Floor($posNow / 60), ($posNow % 60)
            $tE = '{0}:{1:d2}' -f [int][math]::Floor($sp.len / 60), ($sp.len % 60)
            try { [Console]::SetCursorPosition(0, $progRow); Write-Host "$DIM   $tS $R$AC$bar$R$DIM $tE$R" -NoNewline } catch { }
        }
        if (((Get-Date) - $lastFetch).TotalSeconds -ge 4) {
            $sp2 = Get-SpotifyNow; $lastFetch = Get-Date
            if ("$(if ($sp2) { $sp2.title })" -ne $spTitle) { $redraw = $true }
            $sp = $sp2
        }
        Start-Sleep -Milliseconds 160
    }
}
