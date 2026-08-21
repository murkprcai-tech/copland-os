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
5. `COPLAND_ROOT`: Windows `[Environment]::SetEnvironmentVariable('COPLAND_ROOT', <root>, 'User')`,
   macOS `export COPLAND_ROOT=<root>` in `~/.zprofile`
6. claude bits: statusline scripts to `~/.claude/`, `copland.json` to
   `~/.claude/themes/`, skills to `~/.claude/skills/`; register `statusLine`
   in `~/.claude/settings.json` (show the JSON, do not overwrite other keys)
7. terminal: Windows -> explain the "COPLAND OS" profile (see SETUP.md step 4)
   and offer to write it into Windows Terminal `settings.json` (ask first);
   macOS -> run `setup/macos.sh <root>`
8. adjust `$areas` in `copland.ps1` if the area names differ from the default

## 4. Finish

Run the state generator (`copland-state.ps1`), show `STATE.md`, then three lines:

    done. root: <root>
    launcher: <how to start>
    next: open a project, say "we work on <alias>" -- claude reads its CLAUDE.md

Offer (do not do unprompted): a second pass for `_unsorted/` folders, and
`/briefing` if calendar/mail connectors exist.
