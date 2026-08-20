# Setup

## Windows (primary)

1. Create your life-area folders, e.g. in OneDrive or any root:

       00_System  10_uni  20_work  30_venture  40_private  50_career

2. Clone this repo and copy `copland/` into `00_System/copland/`.
3. Copy `claude/copland-statusline.ps1` (and the subagent variant) into `~/.claude/`
   and register it in `~/.claude/settings.json` under `statusLine`.
   Copy `claude/copland.json` into `~/.claude/themes/`.
4. Windows Terminal: create a profile "COPLAND OS" whose commandline runs
   `powershell -NoLogo -NoExit -ExecutionPolicy Bypass -File <path>\copland\copland.ps1`,
   black background, your mono font, `scrollbarState: hidden`, padding `32, 16`.
   Optionally a second hidden profile "COPLAND PANEL" for the sidebar.
5. Adjust the area names inside `copland.ps1` (`$areas`) and the session-folder
   prefix in `Get-AreaPulse`/`Get-AreaBalance` (they match the mangled path of
   YOUR project directory, e.g. `C--Users-<you>-OneDrive-`).
6. Optional free AI council voices: create free keys at openrouter.ai and
   console.groq.com and store them as user environment variables
   `OPENROUTER_API_KEY` / `GROQ_API_KEY` (also supported: `GEMINI_API_KEY`,
   `MISTRAL_API_KEY`). No payment method required -- the helper only ever
   calls `:free` models.

## macOS (experimental)

- Install `pwsh` (PowerShell 7) and a sixel-capable terminal (iTerm2, WezTerm).
- The scripts use `$env:USERPROFILE`, `$env:LOCALAPPDATA` and Windows Terminal
  (`wt`) calls for pane splitting -- replace those with your terminal's own
  split mechanism. The panel, state generator and council helper are portable
  with minor path changes.

## Notes

- Everything is plain files + git. No database, no daemon.
- The AI context convention: every project folder carries a `CLAUDE.md`
  (purpose / status / rules, plus a one-line header with aliases and links).
  The state generator harvests those into a single `STATE.md`.
