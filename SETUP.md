# Setup

Everything lives under one root folder that contains your life areas
(`00_System`, `10_uni`, `20_work`, ...). Default root: `~/OneDrive`.
Set `COPLAND_ROOT` to use any other folder.

## Windows (primary)

1. Create your life-area folders, e.g. in OneDrive or any root:

       00_System  10_uni  20_work  30_venture  40_private  50_career

2. Clone this repo and copy `copland/` into `00_System/copland/`.
3. Copy `claude/copland-statusline.ps1` (and the subagent variant) into `~/.claude/`
   and register it in `~/.claude/settings.json` under `statusLine`.
   Copy `claude/copland.json` into `~/.claude/themes/`.
   Copy `claude/skills/*` into `~/.claude/skills/` (optional, see README "Skills").
4. Windows Terminal: create a profile "COPLAND OS" whose commandline runs
   `powershell -NoLogo -NoExit -ExecutionPolicy Bypass -File <root>\00_System\copland\copland.ps1`,
   black background, your mono font, `scrollbarState: hidden`, padding `32, 16`.
   Optionally a second hidden profile "COPLAND PANEL" for the sidebar
   (the launcher splits it in automatically when it runs inside Windows Terminal).
5. If your root is not `~\OneDrive`: set a user environment variable
   `COPLAND_ROOT=<root>`.
6. Adjust the area names inside `copland.ps1` (`$areas`) if yours differ.
7. Optional free AI council voices: create free keys at openrouter.ai and
   console.groq.com and store them as user environment variables
   `OPENROUTER_API_KEY` / `GROQ_API_KEY` (also supported: `GEMINI_API_KEY`,
   `MISTRAL_API_KEY`). No payment method required -- the helper only ever
   calls `:free` models.

## macOS (experimental)

The scripts are PowerShell and run under `pwsh` (PowerShell 7). Windows-only
bits (Windows Terminal pane split, `%LOCALAPPDATA%`, `explorer`) are detected
and replaced at runtime: cache goes to `~/.cache/copland`, files open with
`open`, the panel is started by the terminal instead of by the launcher.

One-liner (Homebrew required):

    git clone <this repo> && cd copland-os
    bash setup/macos.sh ~/copland        # your root folder; default ~/copland

It installs `pwsh`, WezTerm and Departure Mono, creates the area folders,
copies scripts / statusline / theme / skills, writes `~/.wezterm.lua` (launcher
left, panel right, `^` = new tab, `alt+arrows` = switch tabs) and exports
`COPLAND_ROOT` in `~/.zprofile`. Open WezTerm -- you are in the launcher.

Prefer iTerm2? Use any sixel-capable terminal and run
`pwsh -NoLogo -NoExit -File <root>/00_System/copland/copland.ps1` yourself;
open a second narrow pane with `copland-panel.ps1`.

Known limits on macOS (honest list -- built on Windows, **not tested on a Mac**):

- sixel graphics page needs the `Sixel` PowerShell module + System.Drawing;
  without it the panel silently shows the text pages only.
- the hub's "open in browser" and the workshop's "open file" use `open`.
- the state generator runs fine; the statusline expects Claude Code's
  `statusLine` JSON on stdin as on Windows.
- paths inside the scripts are written with backslashes; `pwsh` on macOS
  normalises them in its own cmdlets, but if something does not find a file,
  that is the first place to look. Issues and PRs welcome.

## Notes

- Everything is plain files + git. No database, no daemon.
- The AI context convention: every project folder carries a `CLAUDE.md`
  (purpose / status / rules, plus a one-line header with aliases and links).
  The state generator harvests those into a single `STATE.md`.
