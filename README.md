![COPLAND OS](docs/banner.svg)

> present day. present time.

A terminal-centered personal operating environment for working with AI assistants,
inspired by the aesthetics of *Serial Experiments Lain*: pure black, cold blue-gray,
pure ASCII, function over decoration.

Built by **Marko Piric**.

![launcher](docs/screenshot.png)

*The launcher: one key per life area, a few keys for tools. Nothing else on screen.*

## Why

Five life areas, two dozen projects, one head. Every AI session used to start with
"where were we?". Copland OS makes the folder structure itself the memory: the
launcher knows the areas, every project carries its context, and a single generated
file tells the AI what is going on everywhere. You press one key and are back inside
the right project with the right context -- nothing to explain.

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

  <img src="docs/panel.png" width="300" alt="panel">

- **STATE.md generator** -- machine-readable snapshot of all projects, aliases,
  deadlines and cross-project links; the AI reads your whole world in one file
- **Hub** -- terminal dashboard + self-contained HTML command center
  (gauges, donut, heatmap, force-directed life graph, commit timeline)
- **The Council (`/rat`)** -- ask Claude, GPT, NVIDIA Nemotron, Meta Llama and
  Alibaba Qwen the same question in parallel, get a synthesis plus a
  "where they disagree" block; the extra voices run on free API tiers (0 EUR)
- **Ambient mode** -- fullscreen clock + limits + rain when you are not working

## How it fits together

![architecture](docs/architecture.svg)

Everything is plain files: folders are life areas, each project carries a `CLAUDE.md`,
a generator folds all of them into one `STATE.md`, and the AI reads that single file
to know where you are. No database, no daemon, no framework.

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
    docs/      screenshots (launcher, panel), animated banner, architecture diagram (svg)

## License

MIT (c) Marko Piric -- see [LICENSE](LICENSE).
