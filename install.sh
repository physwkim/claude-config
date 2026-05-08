#!/usr/bin/env bash
# Install / re-install personal AI CLI config from this repo into the
# config dirs of any installed agent CLIs (claude, codex). Idempotent:
# existing files are backed up with a timestamp suffix before being
# replaced with a symlink.
#
# Usage:  ./install.sh

set -euo pipefail

repo_dir="$(cd "$(dirname "$0")" && pwd -P)"
ts="$(date +%Y%m%d-%H%M%S)"

# Map: <cli-binary> <config-dir> <dest-filename>
# CLAUDE.md from this repo is symlinked to each CLI's global
# instruction file (claude → CLAUDE.md, codex → AGENTS.md).
targets=(
  "claude $HOME/.claude CLAUDE.md"
  "codex  $HOME/.codex  AGENTS.md"
)

link_one() {
  local src="$1"
  local dst="$2"
  local label="$3"

  if [[ ! -e "$src" ]]; then
    echo "skip $label — source $src not in repo"
    return
  fi

  # Already symlinked to this exact source? Nothing to do.
  if [[ -L "$dst" && "$(readlink "$dst")" == "$src" ]]; then
    echo "ok   $label — already linked"
    return
  fi

  # Existing file or wrong-target symlink → back up first.
  if [[ -e "$dst" || -L "$dst" ]]; then
    local bak="$dst.bak.$ts"
    mv "$dst" "$bak"
    echo "back $label -> $bak"
  fi

  ln -s "$src" "$dst"
  echo "link $label -> $src"
}

installed_any=0
for entry in "${targets[@]}"; do
  read -r bin dir name <<< "$entry"

  if ! command -v "$bin" >/dev/null 2>&1; then
    echo "skip $bin — binary not found in PATH"
    continue
  fi

  mkdir -p "$dir"
  link_one "$repo_dir/CLAUDE.md" "$dir/$name" "$bin:$name"
  installed_any=1
done

if [[ "$installed_any" -eq 0 ]]; then
  echo
  echo "No supported CLI binaries (claude, codex) found in PATH."
  exit 1
fi

echo
echo "Done."
