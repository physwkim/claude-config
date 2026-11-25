#!/usr/bin/env bash
# Install / re-install personal AI CLI config from this repo into the
# config dirs of any installed agent CLIs (claude, codex) and caucus. Idempotent:
# existing files are backed up with a timestamp suffix before being
# replaced with a symlink.
#
# Usage:  ./install.sh

set -euo pipefail

repo_dir="$(cd "$(dirname "$0")" && pwd -P)"
ts="$(date +%Y%m%d-%H%M%S)"

# The generic merge of a repo partial into a user file. Objects merge
# key by key and the repo wins a scalar, but an array keeps the user's
# entries in order and appends the repo's missing ones: a merge never
# removes an entry the user had.
merge_def='
def merge($a; $b):
  if ($a | type) == "object" and ($b | type) == "object" then
    reduce ($b | keys_unsorted[]) as $k ($a; .[$k] = merge($a[$k]; $b[$k]))
  elif ($a | type) == "array" and ($b | type) == "array" then
    $a + ($b - $a)
  else $b end;
'

# jq program for the settings merge. Slurped inputs: [0] the user's
# settings.json, [1] settings.partial.json. $repo carries this repo's
# hook entries with paths already resolved (event -> [group]).
#
# merge is the generic repo-keys-win merge. The hooks pass then
# runs on its result and is deliberately NOT that merge: it drops only
# the entries this repo owns — command basename listed in $repo, which
# is what makes a re-run from a moved clone rewrite the path instead of
# duplicating it — then splices the repo entries back in, appending to
# the group with the same matcher if one exists and adding a new group
# if not. Entries the repo does not own are never removed.
hook_merge_prog='
def strip_managed($names):
  with_entries(
    .value |= (
      map(.hooks |= map(select(
            ((.command // "") | split("/") | last) as $b
            | ($names | index($b)) == null)))
      | map(select((.hooks | length) > 0))
    )
  )
  | with_entries(select((.value | length) > 0));
def add_groups($repo):
  reduce ($repo | to_entries[]) as $e (.;
    reduce ($e.value[]) as $g (.;
      (.[$e.key] // []) as $cur
      | ($cur | map(.matcher // "") | index($g.matcher // "")) as $i
      | if $i == null
        then .[$e.key] = ($cur + [$g])
        else .[$e.key] = ($cur | .[$i].hooks += ($g.hooks - .[$i].hooks))
        end));
[$repo | to_entries[] | .value[] | .hooks[]? | .command | split("/") | last] as $names
| merge(.[0]; .[1]) as $merged
| (($merged.hooks // {}) | strip_managed($names) | add_groups($repo)) as $h
| if ($h | length) > 0 then $merged | .hooks = $h else $merged end
'

# Map: <cli-binary> <config-dir> <dest-filename>
# CLAUDE.md from this repo is symlinked to each CLI's global
# instruction file (claude → CLAUDE.md, codex → AGENTS.md).
targets=(
  "claude $HOME/.claude CLAUDE.md"
  "codex  $HOME/.codex  AGENTS.md"
)

# $1, or $1.1, $1.2, ... if taken. $ts has one-second resolution, so a
# second run in the same second would otherwise mv a backup into the
# directory an earlier backup link points at, or cp over that backup.
free_path() {
  local p="$1" i=0
  while [[ -e "$p" || -L "$p" ]]; do p="$1.$((++i))"; done
  printf '%s\n' "$p"
}

link_one() {
  local src="$1"
  local dst="$2"
  local label="$3"
  # Where an existing $dst is moved: beside it unless the caller says otherwise.
  local bak="${4:-$dst.bak.$ts}"

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
    mkdir -p "$(dirname "$bak")"
    bak="$(free_path "$bak")"
    mv "$dst" "$bak"
    echo "back $label -> $bak"
  fi

  ln -s "$src" "$dst"
  echo "link $label -> $src"
}

# Delete the links in $1 that point into $2 at an entry the link loops no
# longer install: one without the file "$entry$3". A link pointing
# anywhere else was not made by this script and stays.
prune_links() {
  local dir="$1" srcdir="$2" need="$3" label="$4" dst tgt
  for dst in "$dir"/*; do
    [[ -L "$dst" ]] || continue
    tgt="$(readlink "$dst")"
    [[ "$tgt" == "$srcdir"/* && ! -f "$tgt$need" ]] || continue
    rm "$dst"
    echo "drop $label/${dst##*/} — $tgt no longer in repo"
  done
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

# Claude-only: one symlink per skills/<name>/ under ~/.claude/skills/,
# so skills installed by other means stay. An existing skill is backed
# up outside ~/.claude/skills: Claude loads every directory there, so a
# backup beside it would load as a second copy of the skill.
if command -v claude >/dev/null 2>&1 && [[ -d "$repo_dir/skills" ]]; then
  mkdir -p "$HOME/.claude/skills"
  for src in "$repo_dir"/skills/*/; do
    src="${src%/}"
    [[ -f "$src/SKILL.md" ]] || continue
    name="$(basename "$src")"
    link_one "$src" "$HOME/.claude/skills/$name" "claude:skills/$name" \
      "$HOME/.claude/skills.bak.$ts/$name"
  done
fi

# Outside the -d guards above: removing the last command or skill removes
# its directory, and that is when stale links are left. A removed skill's
# directory can survive a pull through ignored files (__pycache__), so a
# skill counts as removed once its SKILL.md is gone.
if command -v claude >/dev/null 2>&1; then
  prune_links "$HOME/.claude/commands" "$repo_dir/commands" "" "claude:commands"
  prune_links "$HOME/.claude/skills" "$repo_dir/skills" "/SKILL.md" "claude:skills"
fi

# caucus: global settings.toml. A symlink, like CLAUDE.md, because
# caucus only reads it; per-machine overrides belong in the project
# layer, <repo>/.caucus/settings.toml.
if command -v caucus >/dev/null 2>&1; then
  mkdir -p "$HOME/.caucus"
  link_one "$repo_dir/caucus/settings.toml" "$HOME/.caucus/settings.toml" "caucus:settings.toml"
fi

# Claude-only: merge repo-managed settings into ~/.claude/settings.json.
# We MERGE (not symlink) because settings.json also holds machine-
# specific entries (tool paths, plugins, external hooks) that must
# survive a reinstall. Repo keys win on conflict, so re-running enforces
# them; everything else in the user's file is preserved.
#
# Hooks are merged separately, entry by entry, and live in their own
# hooks.partial.json — NOT in settings.partial.json. The generic merge
# would keep a hook's old path beside the new one after a moved clone,
# since an array union cannot tell the two are one entry. The
# invariant here is that a merge never removes a hook the user had:
# install.sh owns only the entries whose command basename appears in
# hooks.partial.json, rewriting their path to this clone, and leaves
# every other entry alone.
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
      # Repo hook entries with {{REPO}} resolved to this clone. Done in
      # jq, not sed, so a path with shell/JSON metacharacters survives.
      hooks_json='{}'
      if [[ -f "$repo_dir/hooks.partial.json" ]]; then
        if ! hooks_json="$(jq -c --arg repo "$repo_dir" \
             'walk(if type == "string" then gsub("\\{\\{REPO\\}\\}"; $repo) else . end)' \
             "$repo_dir/hooks.partial.json" 2>/dev/null)"; then
          echo "warn claude:settings.json — hooks.partial.json unreadable, hooks left untouched"
          hooks_json='{}'
        fi
      fi

      tmp="$(mktemp)"
      # Compare canonicalised JSON, not bytes: Claude Code rewrites these
      # files itself, and jq's formatting of identical data would
      # otherwise look like a change and trigger a needless rewrite.
      if jq -s --argjson repo "$hooks_json" "$merge_def$hook_merge_prog" \
              "$settings" "$repo_dir/settings.partial.json" > "$tmp" \
         && ! diff -q <(jq -S . "$settings") <(jq -S . "$tmp") >/dev/null 2>&1; then
        bak="$(free_path "$settings.bak.$ts")"
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
    if jq -s "$merge_def merge(.[0]; .[1])" "$gconfig" "$repo_dir/claude-json.partial.json" > "$tmp" \
       && [[ -s "$tmp" ]] \
       && ! diff -q <(jq -S . "$gconfig") <(jq -S . "$tmp") >/dev/null 2>&1; then
      bak="$(free_path "$gconfig.bak.$ts")"
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
