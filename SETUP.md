# Setup

Everything lives under one root folder that contains your life areas
(`00_System`, `10_uni`, `20_work`, ...). Default root: `~/OneDrive` if it exists,
otherwise `~/copland`. `COPLAND_ROOT` points anywhere else.

The scripts are the same on every platform. They detect the system at runtime
(Windows PowerShell 5.1 / pwsh 7 on Windows, pwsh 7 on macOS and Linux) and pick
the matching terminal, cache folder, credentials store and file opener themselves.
There is nothing to configure per platform -- one installer does it all.

## One command

| platform | run inside the cloned repo |
|---|---|
| **Windows** | `powershell -ExecutionPolicy Bypass -File setup/install.ps1` |
| **macOS** | `bash setup/macos.sh` (installs pwsh + WezTerm + font via Homebrew, then runs the installer) |
| **Linux** | `pwsh -File setup/install.ps1` (needs pwsh 7; WezTerm optional) |

Add `-Root <folder>` (or the folder as first argument to `macos.sh`) to choose
another root. Re-run after `git pull` to refresh the scripts -- the installer is
idempotent and never overwrites your own files (`CLAUDE.md`s, `.wezterm.lua`,
terminal profiles that already exist).

What `setup/install.ps1` does, identically on all three systems:

1. creates the life-area folders under the root (existing ones untouched)
2. copies `copland/` to `<root>/00_System/copland/`
3. copies statusline scripts, color theme, skills and the answer style into `~/.claude/`
   and registers `statusLine` in `~/.claude/settings.json` (merge, backup written)
4. persists `COPLAND_ROOT` (Windows: user environment variable; macOS: `~/.zprofile`; Linux: `~/.profile`)
5. terminal: Windows -> adds the "COPLAND OS" + hidden "COPLAND PANEL" profiles, the
   color scheme and the keys (`^` new tab, `alt+left/right`) to Windows Terminal
   (backup written); macOS/Linux -> writes `~/.wezterm.lua` from `setup/wezterm.lua`
   if you have none
6. generates the first `STATE.md`

## Or let Claude do it

Open the cloned repo in Claude Code and say `/setup`. It scans your folders
read-only, proposes the structure as a table, builds it after your go and runs
the installer for your platform.

## How the platform detection works (for the curious)

`copland/copland-shared.ps1` is dot-sourced by every script and sets
`$IsWin / $IsMac / $IsLin`, the cache folder (`%LOCALAPPDATA%` or `~/.cache/copland`),
`$PSExe` (`powershell` or `pwsh`) and a few helpers:

| concern | Windows | macOS / Linux |
|---|---|---|
| panel split | `wt split-pane` (Windows Terminal) | `wezterm cli split-pane` or `tmux split-window`; other terminals: start `copland-panel.ps1` in a second pane yourself |
| open file / folder / url | `Start-Process` | `open` / `xdg-open` |
| Claude usage limits | `~/.claude/.credentials.json` | macOS keychain (`security find-generic-password`) or the json if present |
| system line (disk / ram) | CIM | `sysctl` + `vm_stat` / `/proc/meminfo` |
| council api keys | user environment variables | exported in your shell profile |
| sixel graphics page | Windows Terminal >= 1.22 + `Sixel` module | not available (System.Drawing is Windows-only) -- the text pages are identical |

Everything else is plain PowerShell and behaves the same everywhere. Paths inside
the scripts are built with `Join-Path` / forward slashes, which both platforms accept.

## Manual route (if you prefer)

1. Create the area folders, copy `copland/` into `<root>/00_System/copland/`.
2. Copy `claude/copland-statusline.ps1` (+ subagent variant) into `~/.claude/`,
   `claude/copland.json` into `~/.claude/themes/`, `claude/skills/*` into `~/.claude/skills/`.
   Register in `~/.claude/settings.json`:

       "statusLine": { "type": "command", "command": "pwsh -NoProfile -File \"<home>/.claude/copland-statusline.ps1\"", "refreshInterval": 60 }

   (Windows: `powershell.exe -NoProfile -ExecutionPolicy Bypass -File ...`)
3. Set `COPLAND_ROOT` if your root is not `~/OneDrive`.
4. Terminal: run `pwsh -NoLogo -NoExit -File <root>/00_System/copland/copland.ps1`
   (Windows: `powershell.exe ... -ExecutionPolicy Bypass -File ...`) as the
   profile command; black background, your mono font, padding `32, 16`, no scrollbar.
5. Adjust `$areas` in `copland.ps1` if your area names differ.
6. Optional council voices: free keys from openrouter.ai / console.groq.com as
   `OPENROUTER_API_KEY` / `GROQ_API_KEY` (also `GEMINI_API_KEY`, `MISTRAL_API_KEY`).

## Honest note

Copland was built and is used daily on Windows 11. The macOS/Linux path is the
same code with the platform branches above; it was reviewed line by line and
parsed under pwsh, but the author has no Mac on the desk. If something is off,
open an issue with the line -- it will be a one-liner.
