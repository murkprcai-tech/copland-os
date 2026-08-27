---
name: setup
description: Copland first-run -- scan the machine (read-only), propose life areas and a home for every existing project, build the folder structure with CLAUDE.md files, install launcher/statusline/skills, generate STATE.md. Use on "/setup", "set up copland", "build my structure", or when the repo is opened on a machine without a Copland root.
---

# /setup -- build a Copland structure for this machine

Goal: in one session, turn a loose home folder into life areas with context files,
so the launcher and STATE.md work. The user stays in control of every move.
Tone: lowercase, short, tables instead of prose.

## 0. Ground rules (say them once, then keep them)

- scan is read-only; **nothing moves until the user confirms a table row**
- **never delete**. no "cleanup". duplicates and junk get listed, not removed
- folder names and file counts only -- never quote document contents
- private-looking folders: name them, do not describe them

## 1. Scan

Read-only, shallow (depth 2 is enough). Collect: path, subfolder count, file
count, newest modification date, rough kind (code / documents / media / mixed).

    Windows: $HOME, $HOME\OneDrive, $HOME\Documents, $HOME\Desktop, $HOME\Downloads,
             $HOME\Dropbox, $HOME\Google Drive, $HOME\iCloudDrive, dev roots (src, dev, code, repos)
    macOS:   $HOME, ~/Documents, ~/Desktop, ~/Downloads, ~/Library/CloudStorage/*,
             ~/Library/Mobile Documents/com~apple~CloudDocs, ~/dev, ~/src, ~/code

Skip: hidden folders, `node_modules`, `venv`, `.git`, `AppData`, `Library` (except
CloudStorage), anything over ~5000 files (note it as "large, left alone").

## 2. Propose

Show ONE table. Default area scheme (user renames freely):

| nr | area | holds |
|---|---|---|
| `00_System` | system | copland, templates, backups, this repo's scripts |
| `10_<work-or-study>` | main job / study | |
| `20_<second-job>` | second job, family business, freelance | |
| `30_venture` | own projects that should earn money | |
| `40_private` | private -- highest confidentiality | |
| `50_career` | applications, CVs, certificates | |
| `60_assistent` | personal assistant: brain (cross-project memory), reminders, mails/calendar -- launcher `[a]` | |
| `80_general` | general chat: dump thoughts, `inbox.md` is sorted nightly -- launcher `[g]` (`templates/GENERAL-CLAUDE.md` + empty `inbox.md`) | |
| `90_archive` | finished, read-only | |

Only propose areas that have content. Then the mapping:

| existing folder | -> area/project | why | move? |
|---|---|---|---|
| `~/Documents/Thesis` | `10_uni/thesis` | docs, last change 2026-05 | ? |
| `~/dev/shop-app` | `30_venture/shop-app` | code, git repo | ? |
| `~/Desktop/scan0123.pdf` + 14 more | `_unsorted/` in the nearest area | loose files | ? |

Rules for the mapping: one project = one folder. Git repos stay git repos
(move the whole folder, never its contents). Cloud-synced roots: create the
areas INSIDE the cloud root if that is where most content already lives.
Unsure -> `_unsorted/` inside the most likely area, never guessed hard.

Ask: "edit rows, or go?" Wait for the answer.

## 3. Build

For every confirmed row, in this order:

1. create area folders + `00_System/copland/` (copy `copland/` from this repo)
2. root `CLAUDE.md` from `templates/ROOT-CLAUDE.md` -- fill the area table, leave
   the rules as they are (they are the point)
3. per project: `CLAUDE.md` from `templates/PROJECT-CLAUDE.md` -- header line
   `Bereich/Area: X | status: active | alias: <two or three call-words>`,
   purpose in one line from what the folder name and file kinds suggest (not
   from reading documents), status "set up by /setup on <date>"
4. moves: only rows marked "move"; `Move-Item`/`mv` the whole folder; after each
   batch a recap "moved: a -> b" -- the user reads it before the next batch
5. run the installer -- it detects the platform and does `COPLAND_ROOT`, the
   claude bits (statusline/theme/skills/answer style, `statusLine` merged into
   `~/.claude/settings.json` with a backup) and the terminal profile in one go:

       Windows:  powershell -ExecutionPolicy Bypass -File setup/install.ps1 -Root <root>
       macOS:    bash setup/macos.sh <root>      (brew: pwsh, wezterm, font -> then install.ps1)
       Linux:    pwsh -File setup/install.ps1 -Root <root>

   tell the user what it will touch (Windows Terminal settings.json / ~/.wezterm.lua,
   ~/.claude/settings.json -- both backed up) and ask once before running it
6. adjust `$areas` in `copland.ps1` if the area names differ from the default

## 3b. Connect what you have (ask, do not assume)

One question block, yes/no per line. Each "yes" gets installed/explained; each
"no" simply leaves that part of the panel/launcher empty -- the panel shows only
what is connected (no codex log = no codex row, no keys = no council row,
no ollama = `[o]` warns and returns).

| connect? | what it gives you | how |
|---|---|---|
| **answer style** | the copland voice: short, essence first (`claude/output-styles/concise.md` + `templates/GLOBAL-CLAUDE.md`) | copy style to `~/.claude/output-styles/`, set `"outputStyle": "concise"` in `~/.claude/settings.json`; copy template to `~/.claude/CLAUDE.md` if none exists, else show it for merging |
| **codex cli** (openai) | second opinion via `/dual` and `/council`, codex limits in the panel | `npm i -g @openai/codex`, `codex login`; panel reads `~/.codex/sessions` |
| **local models** (ollama) | `[o]` in the launcher: offline chat, no tokens spent | install ollama, `ollama pull gpt-oss:20b` (or any model); launcher lists what is pulled |
| **council keys** (free) | nemotron / llama / qwen voices in `/council`, remaining calls in the panel | `OPENROUTER_API_KEY`, `GROQ_API_KEY` as user env vars -- free tiers, no card |
| **calendar + mail** | `/briefing` with real events and mails | Google Calendar / Gmail connectors in claude code (MCP) -- the user sets these up in the claude.ai connectors page, you only check whether they exist |
| **sixel graphics** | token curves / model split page in the panel (`alt+g`) | Windows Terminal >= 1.22 + `Install-Module Sixel`; skip on terminals without sixel |

Then restart the launcher so the panel picks the new sources up.

## 4. Finish

Run the state generator (`copland-state.ps1`), show `STATE.md`, then three lines:

    done. root: <root>
    launcher: <how to start>
    next: open a project, say "we work on <alias>" -- claude reads its CLAUDE.md

Offer (do not do unprompted): a second pass for `_unsorted/` folders, and
`/briefing` if calendar/mail connectors exist.
