#!/usr/bin/env bash
# COPLAND OS -- macOS setup (experimental)
# installs: PowerShell 7 (pwsh), Departure Mono, WezTerm (sixel-capable terminal),
# drops a WezTerm config that opens the launcher with the panel on the right.
# run:  bash setup/macos.sh [/path/to/your/root]
#       root = the folder that contains 00_System, 10_uni, ... (default: ~/copland)
set -euo pipefail

ROOT="${1:-$HOME/copland}"
HERE="$(cd "$(dirname "$0")/.." && pwd)"

say() { printf '\033[38;2;140;171;198m%s\033[0m\n' "$*"; }
dim() { printf '\033[38;2;74;88;102m%s\033[0m\n' "$*"; }

say "copland os -- macos setup"
dim "root: $ROOT"

command -v brew >/dev/null || { echo "homebrew missing: https://brew.sh"; exit 1; }

# 1 runtime + terminal + font
brew list --cask powershell   >/dev/null 2>&1 || brew install --cask powershell
brew list --cask wezterm      >/dev/null 2>&1 || brew install --cask wezterm
brew tap | grep -q homebrew/cask-fonts || brew tap homebrew/cask-fonts >/dev/null 2>&1 || true
brew list --cask font-departure-mono >/dev/null 2>&1 || brew install --cask font-departure-mono || dim "font-departure-mono not in brew -- get it from https://departuremono.com"

# 2 folders
mkdir -p "$ROOT"/{00_System,10_uni,20_work,30_venture,40_private,50_career}
mkdir -p "$ROOT/00_System/copland" "$HOME/.claude/themes" "$HOME/.claude/skills" "$HOME/.cache/copland"

# 3 scripts + claude bits
cp -R "$HERE/copland/." "$ROOT/00_System/copland/"
cp "$HERE/claude/copland-statusline.ps1" "$HERE/claude/copland-subagent-statusline.ps1" "$HOME/.claude/"
cp "$HERE/claude/copland.json" "$HOME/.claude/themes/"
cp -R "$HERE/claude/skills/." "$HOME/.claude/skills/"
mkdir -p "$HOME/.claude/output-styles" && cp "$HERE/claude/output-styles/concise.md" "$HOME/.claude/output-styles/"
[ -f "$HOME/.claude/CLAUDE.md" ] || cp "$HERE/templates/GLOBAL-CLAUDE.md" "$HOME/.claude/CLAUDE.md"

# 4 wezterm config (only if none exists)
if [ ! -f "$HOME/.wezterm.lua" ]; then
  sed "s|__ROOT__|$ROOT|g" "$HERE/setup/wezterm.lua" > "$HOME/.wezterm.lua"
  dim "wrote ~/.wezterm.lua"
else
  dim "~/.wezterm.lua exists -- merge setup/wezterm.lua by hand"
fi

# 5 env
PROFILE="$HOME/.zprofile"
grep -q COPLAND_ROOT "$PROFILE" 2>/dev/null || printf '\nexport COPLAND_ROOT="%s"\n' "$ROOT" >> "$PROFILE"

say "done."
dim "next: open WezTerm. launcher = pwsh $ROOT/00_System/copland/copland.ps1"
dim "      register ~/.claude/copland-statusline.ps1 in ~/.claude/settings.json (statusLine)"
dim "      optional council keys: OPENROUTER_API_KEY, GROQ_API_KEY in ~/.zprofile"
