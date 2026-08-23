# COPLAND OS -- one-line bootstrap (windows)
#   irm https://raw.githubusercontent.com/murkprcai-tech/copland-os/main/get.ps1 | iex
# gets git + claude code if missing, clones the repo to ~/copland-os, opens claude inside it.
# claude then reads the repo's CLAUDE.md and offers the guided setup (scan -> proposal -> folders).
# nothing on your machine is moved or deleted by this script.
$ErrorActionPreference = 'Stop'
$E = [char]27; $AC = "$E[38;2;140;171;198m"; $DIM = "$E[38;2;74;88;102m"; $WARN = "$E[38;2;194;132;143m"; $R = "$E[0m"
function Say([string]$m) { Write-Host "$AC  $m$R" }
function Dim([string]$m) { Write-Host "$DIM  $m$R" }

Write-Host ''; Say 'copland os -- present day. present time.'; Write-Host ''

function Has([string]$cmd) { [bool](Get-Command $cmd -ErrorAction SilentlyContinue) }
function Refresh-Path {
    $env:Path = [Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [Environment]::GetEnvironmentVariable('Path','User')
}

# 1 git
if (-not (Has git)) {
    Say 'installing git ...'
    winget install --id Git.Git -e --silent --accept-source-agreements --accept-package-agreements | Out-Null
    Refresh-Path
    if (-not (Has git)) { Write-Host "$WARN  git not found after install -- open a new terminal and run the line again$R"; return }
}

# 2 claude code
if (-not (Has claude)) {
    Say 'installing claude code ...'
    Invoke-RestMethod https://claude.ai/install.ps1 | Invoke-Expression
    Refresh-Path
    $local = Join-Path $env:USERPROFILE '.local\bin'
    if (Test-Path $local) { $env:Path = "$local;$env:Path" }
    if (-not (Has claude)) { Write-Host "$WARN  claude not found after install -- open a new terminal and run the line again$R"; return }
}

# 3 repo
$dest = Join-Path $env:USERPROFILE 'copland-os'
if (Test-Path (Join-Path $dest '.git')) {
    Say "updating $dest"; git -C $dest pull --ff-only | Out-Null
} else {
    Say "cloning to $dest"; git clone --depth 1 https://github.com/murkprcai-tech/copland-os.git $dest | Out-Null
}

# 4 hand over to claude -- the repo's CLAUDE.md takes it from here
Write-Host ''; Dim 'starting claude inside the repo. it will ask before scanning anything.'; Write-Host ''
Set-Location $dest
& claude "hi -- i just ran the one-line bootstrap. please do the first-contact flow from CLAUDE.md."
