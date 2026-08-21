# Master environment -- constitution (applies in every area)

<!-- copy to the root folder that contains your areas. claude code loads it in every
     session below this folder. keep it short: it is read every time. -->

Work happens in life areas. This structure applies to EVERYTHING under this root:

| folder | area |
|---|---|
| `00_System` | system room: copland os, process design, templates, backups. conversations ABOUT the environment |
| `10_<main>` | main job / study |
| `20_<second>` | second job / family business. CRITICAL: delete nothing, keep tax records |
| `30_venture` | own projects that should earn money |
| `40_private` | private. highest confidentiality |
| `50_career` | applications (certificates, cvs). data-protection sensitive |
| `90_archive` | finished. read only |

## Ground rules

1. **Delete only after an explicit question.** Move/rename is fine -- short recap afterwards.
2. New projects: as a subfolder in the right area, never loose in the root or on the desktop.
3. The desktop is a workbench, not storage.
4. Project folders carry a `CLAUDE.md` (header + purpose/status/rules). On entry read it
   first instead of scanning; after every project session update the status there.
   `## Status` keeps max. 3 dated lines -- older ones move to `history.md` in the project.
5. Switching projects by call-word: on "we work on X" resolve X via `00_System/STATE.md`
   (alias column), read that project's `CLAUDE.md`, work there. On "new project X":
   create folder + `CLAUDE.md` from the template, do not ask.
6. Private things (`40_private`, health, passwords/2fa/secrets) only after an explicit
   question; anything visible to the outside (sending mail etc.) gets confirmed first.

## Getting context (targeted reads instead of scanning)

| question | file |
|---|---|
| what is running, which project, links, deadlines? | `00_System/STATE.md` (generated, 1 read) |
| open items (full text) | `00_System/open-items.md` |
| copland os (terminal environment) | `00_System/copland/manual.md` |
| project details | `<project>/CLAUDE.md`, history in `history.md` |

Never edit `STATE.md` by hand (generator: `00_System/copland/copland-state.ps1`).
Project header line: `Area: X | status: active/paused/archive | alias: call-words`
plus optional `Linked: path (verb: why)` and `Deadline: yyyy-mm-dd text`.

## Conventions

New folders: lowercase, hyphens, ascii. `_archive/` = frozen, `_unsorted/` = to be
sorted. Do not force-rename existing names that work. `00_System` is a git repo --
commit after bigger changes.
