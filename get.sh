#!/usr/bin/env bash
# COPLAND OS -- one-line bootstrap (macos / linux)
#   curl -fsSL https://raw.githubusercontent.com/murkprcai-tech/copland-os/main/get.sh | bash
# gets git + claude code if missing, clones the repo to ~/copland-os, opens claude inside it.
# claude then reads the repo's CLAUDE.md and offers the guided setup (scan -> proposal -> folders).
# nothing on your machine is moved or deleted by this script.
set -euo pipefail
say() { printf '\033[38;2;140;171;198m  %s\033[0m\n' "$*"; }
dim() { printf '\033[38;2;74;88;102m  %s\033[0m\n' "$*"; }
echo; say "copland os -- present day. present time."; echo

command -v git >/dev/null || { say "git missing -- install xcode command line tools / your package manager's git, then rerun"; exit 1; }
if ! command -v claude >/dev/null; then
  say "installing claude code ..."
  curl -fsSL https://claude.ai/install.sh | bash
  export PATH="$HOME/.local/bin:$PATH"
  command -v claude >/dev/null || { say "claude not on PATH yet -- open a new terminal and run the line again"; exit 1; }
fi

DEST="$HOME/copland-os"
if [ -d "$DEST/.git" ]; then say "updating $DEST"; git -C "$DEST" pull --ff-only -q
else say "cloning to $DEST"; git clone -q --depth 1 https://github.com/murkprcai-tech/copland-os.git "$DEST"; fi

echo; dim "starting claude inside the repo. it will ask before scanning anything."; echo
cd "$DEST"
exec claude "hi -- i just ran the one-line bootstrap. please do the first-contact flow from CLAUDE.md." </dev/tty
