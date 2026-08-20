# COPLAND OS

> present day. present time.

A terminal-centered personal operating environment for working with AI assistants,
inspired by the aesthetics of *Serial Experiments Lain*: pure black, cold blue-gray,
pure ASCII, function over decoration.

Built by **Marko Piric**.

![screenshot](docs/screenshot.png)

## What it is

Copland OS turns Windows Terminal + PowerShell + [Claude Code](https://claude.com/claude-code)
into a launcher for your whole life: numbered *life areas* (university, work, ventures,
private, career) live as folders, every project carries a context file for the AI,
and a single keypress drops you into an AI session exactly where you left off.

## Features

- **Launcher** -- two-column menu, one key per life area, activity pulse markers,
  digital rain, project cards with last-activity and status
- **Panel** -- a slim live sidebar in every tab: clock, weather, Claude/Codex/free-AI
  usage limits as bars, burn-rate curve (braille), sixel graphics page
  (token curves, model split, activity heatmap) -- switch pages with arrow keys or `alt+g`
- **STATE.md generator** -- machine-readable snapshot of all projects, aliases,
  deadlines and cross-project links; the AI reads your whole world in one file
- **Hub** -- terminal dashboard + self-contained HTML command center
  (gauges, donut, heatmap, force-directed life graph, commit timeline)
- **The Council (`/rat`)** -- ask Claude, GPT, NVIDIA Nemotron, Meta Llama and
  Alibaba Qwen the same question in parallel, get a synthesis plus a
  "where they disagree" block; the extra voices run on free API tiers (0 EUR)
- **Ambient mode** -- fullscreen clock + limits + rain when you are not working

## Requirements

- Windows 11, Windows Terminal >= 1.22 (sixel), PowerShell 5.1+
- [Claude Code](https://claude.com/claude-code) (and optionally the Codex CLI)
- Font: [Departure Mono](https://departuremono.com/) (or any mono font you like)
- Optional: `ccusage` (npm) for token charts, [Sixel](https://www.powershellgallery.com/packages/Sixel)
  PowerShell module, Ollama for offline models

macOS: the scripts are PowerShell -- they run under `pwsh` with a sixel-capable
terminal (iTerm2/WezTerm), but path handling is Windows-first; expect to adapt.
See [SETUP.md](SETUP.md).

## Repository layout

    copland/   launcher, panel, state/hub generators, council helper, manual
    claude/    statusline scripts + Claude Code color theme
    docs/      screenshots

## License

MIT (c) Marko Piric -- see [LICENSE](LICENSE).
