#!/usr/bin/env bash
# Install / re-install personal Claude Code config from this repo
# into ~/.claude. Idempotent: existing files are backed up with a
# timestamp suffix before being replaced with a symlink.
#
# Usage:  ./install.sh

set -euo pipefail

repo_dir="$(cd "$(dirname "$0")" && pwd -P)"
claude_dir="$HOME/.claude"
ts="$(date +%Y%m%d-%H%M%S)"

mkdir -p "$claude_dir"

link_one() {
  local rel="$1"            # path relative to repo and ~/.claude
  local src="$repo_dir/$rel"
  local dst="$claude_dir/$rel"

  if [[ ! -e "$src" ]]; then
    echo "skip $rel — not in repo"
    return
  fi

  # Already symlinked to this exact source? Nothing to do.
  if [[ -L "$dst" && "$(readlink "$dst")" == "$src" ]]; then
    echo "ok   $rel — already linked"
    return
  fi

  # Existing file or wrong-target symlink → back up first.
  if [[ -e "$dst" || -L "$dst" ]]; then
    local bak="$dst.bak.$ts"
    mv "$dst" "$bak"
    echo "back $rel -> $bak"
  fi

  ln -s "$src" "$dst"
  echo "link $rel -> $src"
}

link_one CLAUDE.md

echo
echo "Done. Verify with: ls -la $claude_dir/CLAUDE.md"
