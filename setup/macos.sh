#!/usr/bin/env bash
# COPLAND OS -- macOS bootstrap
# installs what the scripts need (PowerShell 7, WezTerm, Departure Mono) via Homebrew,
# then hands over to setup/install.ps1 -- the same installer Windows and Linux use.
# run:  bash setup/macos.sh [/path/to/your/root]
#       root = the folder that contains 00_System, 10_uni, ... (default: ~/copland)
set -euo pipefail

ROOT="${1:-$HOME/copland}"
HERE="$(cd "$(dirname "$0")/.." && pwd)"

say() { printf '\033[38;2;140;171;198m  %s\033[0m\n' "$*"; }
dim() { printf '\033[38;2;74;88;102m  %s\033[0m\n' "$*"; }

echo
say "copland os -- macos bootstrap"
dim "root: $ROOT"
echo

command -v brew >/dev/null || { echo "homebrew missing: https://brew.sh"; exit 1; }

# 1 runtime + terminal + font (each only if missing)
command -v pwsh    >/dev/null || brew install --cask powershell
command -v wezterm >/dev/null || brew install --cask wezterm
if ! fc-list 2>/dev/null | grep -qi 'departure' && ! ls ~/Library/Fonts /Library/Fonts 2>/dev/null | grep -qi 'departure'; then
  brew install --cask font-departure-mono 2>/dev/null || dim "font-departure-mono not in brew -- get it from https://departuremono.com (WezTerm falls back to JetBrains Mono / Menlo)"
fi

# 2 everything else is platform-neutral -> one installer for all systems
pwsh -NoProfile -File "$HERE/setup/install.ps1" -Root "$ROOT"

dim "next: open WezTerm -- you are in the launcher (panel splits in on the right)."
dim "      claude code: ~/.claude/settings.json now points statusLine at the copland script."
echo
