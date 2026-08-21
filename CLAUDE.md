# Copland OS -- instructions for Claude Code

You are inside the Copland OS repository. Whoever opened this is probably NOT the
author: they got the repo from a colleague and want to see whether it fits their
own machine. Your job on first contact is to **offer to set it up for them** --
not to explain the scripts.

## First contact (do this before anything else)

1. Check whether a Copland root already exists: `$COPLAND_ROOT`, or `~/OneDrive`
   or `~/copland` containing a `00_System/` folder. If yes: read
   `<root>/00_System/STATE.md` and carry on as a normal Copland session.
2. If not, say in two sentences what Copland does (folders = life areas, one
   `CLAUDE.md` per project, one generated `STATE.md`, a launcher that opens Claude
   Code in the right place) and **offer to build the structure for them**:

   > "I can scan your home folders (Documents, Desktop, Downloads, any cloud
   > folder) and propose a set of life areas and a place for each existing
   > project. Nothing gets moved or deleted until you say so. Want that?"

3. On yes: run the `/setup` skill (`claude/skills/setup/SKILL.md`) -- it
   contains the whole procedure. Summary:
   - scan (read-only) top-level folders under `$HOME`, cloud roots
     (OneDrive, iCloud Drive, Dropbox, Google Drive), Desktop, Documents
   - propose 4-6 life areas in the `NN_name` scheme (e.g. `10_uni`, `20_work`,
     `30_venture`, `40_private`, `50_career`) plus `00_System`, and a mapping
     "existing folder -> area" -- as a table, with question marks where unsure
   - let them edit the proposal, then create the folders, the root
     `CLAUDE.md` (from `templates/ROOT-CLAUDE.md`), one `CLAUDE.md` per
     project (from `templates/PROJECT-CLAUDE.md`), and `00_System/copland/`
   - moving existing folders into areas is **opt-in per folder**, always
     with a recap; **never delete anything**
   - run the installer for this platform (it detects the OS itself and does
     folders, scripts, statusline/theme/skills, `COPLAND_ROOT`, terminal profile):
     Windows `powershell -ExecutionPolicy Bypass -File setup/install.ps1 -Root <root>`,
     macOS `bash setup/macos.sh <root>`, Linux `pwsh -File setup/install.ps1 -Root <root>`
   - finish by generating `STATE.md` and showing it

## Rules in this repo

- Privacy: everything the scan finds stays on the machine. Never summarise
  file contents into the proposal -- folder names and counts are enough.
- Private-looking folders (photos, health, finance, passwords, partners'
  names) go to the private area and get **no** content description in
  their `CLAUDE.md` beyond the folder name.
- Keep the Copland tone: lowercase, short, no filler.
- Do not modify the scripts to "fix" someone's setup -- use `COPLAND_ROOT`
  and the `$areas` table in `copland.ps1`.
- Platform: detect it (`$env:OS -eq 'Windows_NT'`, `$IsMacOS`, `$IsLinux`) and
  run the matching line above. The scripts themselves are identical on all
  three -- never tell a macOS user the project is Windows-only.
