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
      # Compare canonicalised JSON, not bytes: Claude Code rewrites these
      # files itself, and jq's formatting of identical data would
      # otherwise look like a change and trigger a needless rewrite.
      if jq -s '.[0] * .[1]' "$settings" "$repo_dir/settings.partial.json" > "$tmp" \
         && ! diff -q <(jq -S . "$settings") <(jq -S . "$tmp") >/dev/null 2>&1; then
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

# Claude-only: merge repo-managed global-config keys into ~/.claude.json.
# This is a DIFFERENT file from settings.json. A handful of Claude Code
# options live only in the global config and are rejected in
# settings.json — see README "Global config merge" for the list.
#
# ~/.claude.json also holds auth, onboarding and per-project state, and a
# running Claude session rewrites it (read-modify-write). So unlike
# settings.json we never create it, and we take Claude's own mutex first:
# proper-lockfile locks with mkdir("<file>.lock"), which `mkdir` here
# reproduces atomically — EEXIST means a session is mid-write.
if command -v claude >/dev/null 2>&1 && [[ -f "$repo_dir/claude-json.partial.json" ]]; then
  gconfig="$HOME/.claude.json"
  gclock="$gconfig.lock"
  if ! command -v jq >/dev/null 2>&1; then
    echo "skip claude:.claude.json — jq not found; install jq to enable merge"
  elif [[ ! -f "$gconfig" ]]; then
    echo "skip claude:.claude.json — $gconfig not found; run claude once, then re-run"
  elif ! jq empty "$gconfig" 2>/dev/null; then
    echo "skip claude:.claude.json — $gconfig is not valid JSON, left untouched"
  elif ! mkdir "$gclock" 2>/dev/null; then
    echo "skip claude:.claude.json — write lock held by a running Claude session; re-run in a moment"
  else
    trap 'rmdir "$gclock" 2>/dev/null || true' EXIT
    # Temp file lives beside the target so the mv is atomic (same fs).
    tmp="$(mktemp "$gconfig.tmp.XXXXXX")"
    if jq -s '.[0] * .[1]' "$gconfig" "$repo_dir/claude-json.partial.json" > "$tmp" \
       && [[ -s "$tmp" ]] \
       && ! diff -q <(jq -S . "$gconfig") <(jq -S . "$tmp") >/dev/null 2>&1; then
      bak="$gconfig.bak.$ts"
      cp "$gconfig" "$bak"
      mv "$tmp" "$gconfig"
      echo "merge claude:.claude.json <- claude-json.partial.json (backup -> $bak)"
    elif [[ -s "$tmp" ]]; then
      rm -f "$tmp"
      echo "ok   claude:.claude.json — repo global-config keys already present"
    else
      rm -f "$tmp"
      echo "skip claude:.claude.json — jq merge failed, left untouched"
    fi
    rmdir "$gclock" 2>/dev/null || true
    trap - EXIT
  fi
fi

if [[ "$installed_any" -eq 0 ]]; then
  echo
  echo "No supported CLI binaries (claude, codex) found in PATH."
  exit 1
fi

echo
echo "Done."
