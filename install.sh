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

# Claude-only: per-file symlinks under ~/.claude/commands/. Each
# command file becomes a `/<name>` slash command.  We symlink
# per-file (not per-directory) so existing user-local commands in
# ~/.claude/commands/ stay untouched.
if command -v claude >/dev/null 2>&1 && [[ -d "$repo_dir/commands" ]]; then
  mkdir -p "$HOME/.claude/commands"
  for src in "$repo_dir"/commands/*.md; do
    [[ -e "$src" ]] || continue
    name="$(basename "$src")"
    link_one "$src" "$HOME/.claude/commands/$name" "claude:commands/$name"
  done
fi

# Claude-only: merge repo-managed settings into ~/.claude/settings.json.
# We MERGE (not symlink) because settings.json also holds machine-
# specific entries (tool paths, plugins, external hooks) that must
# survive a reinstall. Repo keys win on conflict, so re-running enforces
# them; everything else in the user's file is preserved.
if command -v claude >/dev/null 2>&1 && [[ -f "$repo_dir/settings.partial.json" ]]; then
  settings="$HOME/.claude/settings.json"
  if ! command -v jq >/dev/null 2>&1; then
    echo "skip claude:settings.json — jq not found; install jq to enable merge"
  else
    mkdir -p "$HOME/.claude"
    [[ -f "$settings" ]] || echo '{}' > "$settings"
    if ! jq empty "$settings" 2>/dev/null; then
      echo "skip claude:settings.json — $settings is not valid JSON, left untouched"
    else
      tmp="$(mktemp)"
      if jq -s '.[0] * .[1]' "$settings" "$repo_dir/settings.partial.json" > "$tmp" \
         && ! diff -q "$settings" "$tmp" >/dev/null 2>&1; then
        bak="$settings.bak.$ts"
        cp "$settings" "$bak"
        mv "$tmp" "$settings"
        echo "merge claude:settings.json <- settings.partial.json (backup -> $bak)"
      elif [[ -s "$tmp" ]]; then
        rm -f "$tmp"
        echo "ok   claude:settings.json — repo settings already present"
      else
        rm -f "$tmp"
        echo "skip claude:settings.json — jq merge failed, left untouched"
      fi
    fi
  fi
fi

if [[ "$installed_any" -eq 0 ]]; then
  echo
  echo "No supported CLI binaries (claude, codex) found in PATH."
  exit 1
fi

echo
echo "Done."
