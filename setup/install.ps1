# COPLAND OS -- installer (windows / macos / linux, one script)
# detects the platform itself and does the same thing everywhere:
#   1. life-area folders under the root          (nothing existing is touched)
#   2. copland/ scripts -> <root>/00_System/copland/
#   3. claude code bits -> ~/.claude (statusline, theme, skills, answer style, global CLAUDE.md if none)
#   4. statusLine registered in ~/.claude/settings.json (other keys untouched, backup written)
#   5. COPLAND_ROOT persisted (windows: user env var | unix: ~/.zprofile or ~/.profile)
#   6. terminal: windows -> "COPLAND OS" + "COPLAND PANEL" profiles + color scheme in Windows Terminal
#               macos/linux -> ~/.wezterm.lua from setup/wezterm.lua (only if none exists)
# run:  windows   powershell -ExecutionPolicy Bypass -File setup/install.ps1 [-Root <folder>]
#       macos     bash setup/macos.sh [<folder>]        (installs pwsh/wezterm/font, then calls this)
#       linux     pwsh -File setup/install.ps1 [-Root <folder>]
# idempotent: run it again after a git pull to refresh the scripts.

param(
    [string]$Root = '',
    [switch]$NoTerminal,     # skip terminal profile / wezterm config
    [switch]$NoClaude        # skip ~/.claude changes
)
$ErrorActionPreference = 'Stop'

$E = [char]27; $AC = "$E[38;2;140;171;198m"; $DIM = "$E[38;2;74;88;102m"; $WARN = "$E[38;2;194;132;143m"; $R = "$E[0m"
function Say([string]$m) { Write-Host "$AC  $m$R" }
function Dim([string]$m) { Write-Host "$DIM  $m$R" }
function Warn([string]$m) { Write-Host "$WARN  $m$R" }

# --- platform ---------------------------------------------------------------
$IsWin = ($env:OS -eq 'Windows_NT')
$IsMac = [bool](Get-Variable IsMacOS -ValueOnly -ErrorAction SilentlyContinue)
if (-not $env:USERPROFILE) { $env:USERPROFILE = $HOME }
$Home2 = $env:USERPROFILE
$Repo  = Split-Path $PSScriptRoot -Parent
$PSExe = if ($IsWin) { 'powershell' } else { 'pwsh' }
$osName = if ($IsWin) { 'windows' } elseif ($IsMac) { 'macos' } else { 'linux' }

if (-not $Root) {
    $Root = if ($env:COPLAND_ROOT) { $env:COPLAND_ROOT }
            elseif (Test-Path (Join-Path $Home2 'OneDrive')) { Join-Path $Home2 'OneDrive' }
            else { Join-Path $Home2 'copland' }
}
$Root = $Root.TrimEnd('/', '\')

Write-Host ""
Say "copland os -- install ($osName)"
Dim "root: $Root"
Dim "repo: $Repo"
Write-Host ""

# --- 1 folders --------------------------------------------------------------
$areas = '00_System', '10_uni', '20_work', '30_venture', '40_private', '50_career'
foreach ($a in $areas) { $null = New-Item -ItemType Directory -Force -Path (Join-Path $Root $a) }
$copDir = Join-Path $Root '00_System/copland'
$null = New-Item -ItemType Directory -Force -Path $copDir
Dim "folders ok"

# --- 2 scripts --------------------------------------------------------------
Copy-Item (Join-Path $Repo 'copland/*') $copDir -Recurse -Force
$sysCmd = Join-Path $Root '00_System/CLAUDE.md'
if (-not (Test-Path $sysCmd)) {
    @(
        '# 00_System -- system room'
        ''
        'Bereich: SYSTEM | status: aktiv | alias: system, copland'
        ''
        'Copland OS lives in `copland/` (launcher, panel, state generator). `STATE.md` is generated -- never edit by hand.'
    ) | Set-Content $sysCmd -Encoding utf8
}
$rootCmd = Join-Path $Root 'CLAUDE.md'
if (-not (Test-Path $rootCmd) -and (Test-Path (Join-Path $Repo 'templates/ROOT-CLAUDE.md'))) {
    Copy-Item (Join-Path $Repo 'templates/ROOT-CLAUDE.md') $rootCmd
}
$opFile = Join-Path $Root '00_System/offene-punkte.md'
if (-not (Test-Path $opFile)) { "# open points`n`n## next`n- (add items here)`n" | Set-Content $opFile -Encoding utf8 }
Dim "scripts -> $copDir"

# --- 3 claude code bits -----------------------------------------------------
$claudeHome = Join-Path $Home2 '.claude'
if (-not $NoClaude) {
    foreach ($d in 'themes', 'skills', 'output-styles') { $null = New-Item -ItemType Directory -Force -Path (Join-Path $claudeHome $d) }
    Copy-Item (Join-Path $Repo 'claude/copland-statusline.ps1') $claudeHome -Force
    Copy-Item (Join-Path $Repo 'claude/copland-subagent-statusline.ps1') $claudeHome -Force
    Copy-Item (Join-Path $Repo 'claude/copland.json') (Join-Path $claudeHome 'themes') -Force
    Copy-Item (Join-Path $Repo 'claude/skills/*') (Join-Path $claudeHome 'skills') -Recurse -Force
    Copy-Item (Join-Path $Repo 'claude/output-styles/concise.md') (Join-Path $claudeHome 'output-styles') -Force
    $gcmd = Join-Path $claudeHome 'CLAUDE.md'
    if (-not (Test-Path $gcmd)) { Copy-Item (Join-Path $Repo 'templates/GLOBAL-CLAUDE.md') $gcmd }
    Dim "claude bits -> $claudeHome"

    # --- 4 settings.json: statusLine (merge, keep everything else) ---
    $setF = Join-Path $claudeHome 'settings.json'
    $settings = $null
    if (Test-Path $setF) {
        try { $settings = Get-Content $setF -Raw | ConvertFrom-Json } catch { Warn "settings.json unreadable -- statusLine not registered (see SETUP.md)"; $settings = $false }
    }
    if ($settings -ne $false) {
        if (-not $settings) { $settings = [pscustomobject]@{} }
        $slPath = Join-Path $claudeHome 'copland-statusline.ps1'
        $slCmd = if ($IsWin) { "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$slPath`"" } else { "pwsh -NoProfile -File `"$slPath`"" }
        $sl = [pscustomobject]@{ type = 'command'; command = $slCmd; refreshInterval = 60 }
        if ($settings.PSObject.Properties.Name -contains 'statusLine') { $settings.statusLine = $sl }
        else { $settings | Add-Member -NotePropertyName statusLine -NotePropertyValue $sl }
        if (-not ($settings.PSObject.Properties.Name -contains 'outputStyle')) { $settings | Add-Member -NotePropertyName outputStyle -NotePropertyValue 'concise' }
        # --- 4b hooks: guard (write-lock on taboo paths), audit log, toast/sound, vault recall.
        #     merged into existing hooks -- other tools' hooks stay untouched. node is required.
        if (Get-Command node -ErrorAction SilentlyContinue) {
            $hooksDir = Join-Path $copDir 'hooks'
            $wire = @(
                @{ ev = 'PreToolUse';       js = 'copland-guard.js';        t = 5 },
                @{ ev = 'PostToolUse';      js = 'copland-audit.js';        t = 5 },
                @{ ev = 'Notification';     js = 'copland-notify.js';       t = 5 },
                @{ ev = 'Stop';             js = 'copland-notify.js';       t = 5 },
                @{ ev = 'UserPromptSubmit'; js = 'copland-vault-recall.js'; t = 8 }
            )
            if (-not ($settings.PSObject.Properties.Name -contains 'hooks')) { $settings | Add-Member -NotePropertyName hooks -NotePropertyValue ([pscustomobject]@{}) }
            foreach ($w in $wire) {
                $cmd = "node `"$(Join-Path $hooksDir $w.js)`""
                $entry = [pscustomobject]@{ matcher = ''; hooks = @([pscustomobject]@{ type = 'command'; command = $cmd; timeout = $w.t }) }
                $cur = @()
                if ($settings.hooks.PSObject.Properties.Name -contains $w.ev) { $cur = @($settings.hooks.($w.ev)) }
                if (-not ($cur | Where-Object { "$($_.hooks.command)" -like "*$($w.js)*" })) {
                    $cur += $entry
                    if ($settings.hooks.PSObject.Properties.Name -contains $w.ev) { $settings.hooks.($w.ev) = $cur }
                    else { $settings.hooks | Add-Member -NotePropertyName $w.ev -NotePropertyValue $cur }
                }
            }
            Dim "hooks registered (guard, audit, notify, vault-recall)"
        } else { Warn 'node not found -- hooks (guard/audit/notify/vault-recall) not registered; install node and re-run' }
        if (Test-Path $setF) { Copy-Item $setF "$setF.copland-bak" -Force }
        $settings | ConvertTo-Json -Depth 20 | Set-Content $setF -Encoding utf8
        Dim "statusLine registered in settings.json (backup: settings.json.copland-bak)"
    }
}

# --- 5 COPLAND_ROOT ---------------------------------------------------------
if ($IsWin) {
    [Environment]::SetEnvironmentVariable('COPLAND_ROOT', $Root, 'User')
    Dim "COPLAND_ROOT=$Root (user environment)"
} else {
    $prof = if ($IsMac) { Join-Path $Home2 '.zprofile' } else { Join-Path $Home2 '.profile' }
    $line = "export COPLAND_ROOT=`"$Root`""
    $has = (Test-Path $prof) -and ((Get-Content $prof -Raw) -match 'COPLAND_ROOT=')
    if (-not $has) { Add-Content $prof "`n# copland os`n$line" }
    Dim "COPLAND_ROOT in $prof"
}
$env:COPLAND_ROOT = $Root

# --- 6 terminal -------------------------------------------------------------
if (-not $NoTerminal) {
    if ($IsWin) {
        # windows terminal: scheme + two profiles, only if absent. settings.json backed up first.
        $wtF = Get-ChildItem (Join-Path $env:LOCALAPPDATA 'Packages') -Directory -Filter 'Microsoft.WindowsTerminal*' -ErrorAction SilentlyContinue |
               ForEach-Object { Join-Path $_.FullName 'LocalState/settings.json' } | Where-Object { Test-Path $_ } | Select-Object -First 1
        if (-not $wtF) {
            Warn "windows terminal settings.json not found -- create the profile by hand (SETUP.md)"
        } else {
            try {
                $wt = Get-Content $wtF -Raw | ConvertFrom-Json
                $font = 'Departure Mono'   # falls back to the terminal default if not installed
                $scheme = [pscustomobject]@{
                    name = 'Copland OS'; background = '#000000'; foreground = '#B8C4CE'; cursorColor = '#8CABC6'; selectionBackground = '#1C2731'
                    black = '#000000'; red = '#A56A76'; green = '#7C9A8E'; yellow = '#A8A08B'; blue = '#6E8CA6'; purple = '#8688A6'; cyan = '#7FA3B5'; white = '#B8C4CE'
                    brightBlack = '#4A5866'; brightRed = '#C2848F'; brightGreen = '#93B2A6'; brightYellow = '#C0B8A2'; brightBlue = '#8CABC6'; brightPurple = '#A2A4C2'; brightCyan = '#9CC0D2'; brightWhite = '#E1E8EE'
                }
                if (-not $wt.schemes) { $wt | Add-Member -NotePropertyName schemes -NotePropertyValue @() -Force }
                if (-not ($wt.schemes | Where-Object { $_.name -eq 'Copland OS' })) { $wt.schemes = @($wt.schemes) + $scheme }
                $launcher = Join-Path $copDir 'copland.ps1'
                $profMain = [pscustomobject]@{
                    guid = '{a0ec8776-4105-47cf-be34-ce7cfff04d29}'; name = 'COPLAND OS'
                    commandline = "powershell.exe -NoLogo -NoExit -ExecutionPolicy Bypass -File `"$launcher`""
                    startingDirectory = $Root; colorScheme = 'Copland OS'; cursorShape = 'bar'
                    font = [pscustomobject]@{ face = $font; size = 12; cellHeight = '1.45' }
                    padding = '32, 16'; scrollbarState = 'hidden'; antialiasingMode = 'grayscale'
                    backgroundImage = (Join-Path $copDir 'lain-wallpaper.png'); backgroundImageAlignment = 'bottomRight'
                    backgroundImageOpacity = 0.05; backgroundImageStretchMode = 'none'
                }
                $profPanel = [pscustomobject]@{
                    guid = '{145f49d4-fbdd-4261-9480-f214c5e38438}'; name = 'COPLAND PANEL'; hidden = $true
                    startingDirectory = $Root; colorScheme = 'Copland OS'; cursorShape = 'underscore'
                    font = [pscustomobject]@{ face = $font; size = 12; cellHeight = '1.45' }
                    padding = '16, 12'; scrollbarState = 'hidden'; antialiasingMode = 'grayscale'
                }
                $list = @($wt.profiles.list)
                $added = @()
                foreach ($pp in @($profMain, $profPanel)) {
                    if (-not ($list | Where-Object { $_.name -eq $pp.name })) { $list += $pp; $added += $pp.name }
                }
                $wt.profiles.list = $list
                # keys: ^ = new tab, alt+left/right = switch tabs, alt+g = panel graphics page (only if unbound)
                $keys = @(
                    @{ id = 'Terminal.OpenNewTab'; keys = '^' },
                    @{ id = 'Terminal.PrevTab';    keys = 'alt+left' },
                    @{ id = 'Terminal.NextTab';    keys = 'alt+right' }
                )
                if (-not $wt.keybindings) { $wt | Add-Member -NotePropertyName keybindings -NotePropertyValue @() -Force }
                $kb = @($wt.keybindings)
                foreach ($k in $keys) {
                    if (-not ($kb | Where-Object { $_.keys -eq $k.keys })) { $kb += [pscustomobject]$k }
                }
                $wt.keybindings = $kb
                Copy-Item $wtF "$wtF.copland-bak" -Force
                $wt | ConvertTo-Json -Depth 30 | Set-Content $wtF -Encoding utf8
                if ($added) { Dim "windows terminal: added $($added -join ', ') (backup: settings.json.copland-bak)" }
                else { Dim "windows terminal: profiles already there" }
                Dim "tip: settings > startup > default profile = COPLAND OS"
            } catch {
                Warn "windows terminal settings.json could not be edited ($($_.Exception.Message)) -- see SETUP.md step 4"
            }
        }
    } else {
        $wez = Join-Path $Home2 '.wezterm.lua'
        $tpl = Join-Path $Repo 'setup/wezterm.lua'
        $pwshPath = (Get-Command pwsh -ErrorAction SilentlyContinue).Source
        if (-not $pwshPath) { $pwshPath = 'pwsh' }
        if (Test-Path $wez) {
            Dim "~/.wezterm.lua exists -- left untouched (merge setup/wezterm.lua by hand)"
        } elseif (Test-Path $tpl) {
            (Get-Content $tpl -Raw).Replace('__ROOT__', $Root).Replace('__PWSH__', $pwshPath) | Set-Content $wez -Encoding utf8
            Dim "wrote ~/.wezterm.lua (launcher = default program, panel splits in automatically)"
        }
        if (-not (Get-Command wezterm -ErrorAction SilentlyContinue)) {
            Dim "no wezterm found: any terminal works -> $PSExe -NoLogo -NoExit -File $copDir/copland.ps1"
        }
    }
}

# --- 7 first STATE.md -------------------------------------------------------
try { & $PSExe -NoProfile -File (Join-Path $copDir 'copland-state.ps1') | Out-Null } catch { }

Write-Host ""
Say "done."
Dim "launcher:  $PSExe -NoLogo -NoExit -File `"$copDir/copland.ps1`""
if ($IsWin) { Dim "           or open the COPLAND OS profile in windows terminal" }
elseif ($IsMac) { Dim "           or just open wezterm" }
Dim "state:     $Root/00_System/STATE.md"
Dim "areas:     edit `$areas in copland.ps1 if your folder names differ"
Dim "optional:  codex cli, ollama, council keys (OPENROUTER_API_KEY / GROQ_API_KEY) -- panel shows what it finds"
Write-Host ""
