# claude-config

Personal Claude Code configuration, versioned so it stays consistent
across machines.

Currently tracks:

- `CLAUDE.md` — global instructions installed at `~/.claude/CLAUDE.md`
  (and `~/.codex/AGENTS.md` if Codex is installed).
- `commands/*.md` — Claude slash commands installed at
  `~/.claude/commands/<name>.md`. Each file becomes a `/<name>`
  slash command.
- `audit/` — long-form methodology playbooks referenced from the
  slash commands (e.g. `audit/c-parity-audit.md`). Not symlinked
  anywhere; the slash commands cite the in-repo path so the docs
  stay versioned with their commands.
- `hooks/` — executable hook scripts referenced by absolute path
  from `~/.claude/settings.json`. Not symlinked; the settings entry
  points directly at the in-repo file so updates land via `git pull`.
- `settings.partial.json` — repo-managed Claude Code settings keys.
  Not symlinked: `install.sh` **merges** these keys into the existing
  `~/.claude/settings.json` (jq), so machine-specific entries survive.
- `hooks.partial.json` — repo-managed hook registrations, merged into
  the same file but entry by entry rather than by the generic key
  merge, so hooks you registered yourself are never dropped. `{{REPO}}`
  in a command is replaced with this clone's absolute path at install
  time.
- `claude-json.partial.json` — repo-managed **global config** keys, for
  the options Claude Code accepts only in `~/.claude.json` and not in
  `settings.json`. Merged the same way, under Claude's own write lock.

## Before you run install.sh

This is one person's config, not a starter template. `install.sh` writes
to three files outside the repo — `~/.claude/CLAUDE.md` (replaced by a
symlink to this repo), `~/.claude/settings.json` and `~/.claude.json` —
and the settings it merges deliberately loosen Claude Code's defaults:

- `permissions.defaultMode: "auto"` and
  `skipDangerousModePermissionPrompt: true` — fewer permission prompts,
  and no confirmation prompt when starting with
  `--dangerously-skip-permissions`;
- `permissions.allow` runs `git add`, `git commit`, `git push`,
  `cargo check` and `cargo generate-lockfile` without asking. It is an
  array, so on merge it **replaces** your allowlist instead of adding to
  it;
- `attribution` blanks the commit and PR trailers;
- `CLAUDE.md` is a strict working contract — mandated report format,
  banned phrases, English/Korean only — and it applies to every project
  on the machine, not just this one.

Read `settings.partial.json` and `CLAUDE.md` first and drop what you do
not want. Every file is copied to `<file>.bak.<timestamp>` before a
change, so a run is recoverable; note that after install, edits to
`~/.claude/CLAUDE.md` land in this repo through the symlink.

## Install on a new machine

```sh
git clone <this-repo-url> ~/codes/claude-config
cd ~/codes/claude-config
./install.sh
```

`install.sh` symlinks `~/.claude/CLAUDE.md` to this repo's copy. Any
existing `~/.claude/CLAUDE.md` is moved aside to
`~/.claude/CLAUDE.md.bak.<timestamp>` first — never overwritten in
place.

After install, edits in either location go through this repo because
of the symlink. Commit and push from `~/codes/claude-config` to
share across machines.

## Update workflow

```sh
cd ~/codes/claude-config
git pull          # fetch updates from other machines
$EDITOR CLAUDE.md
git commit -am "..."
git push
```

On other machines: `git pull` and the symlink picks up the new
content immediately — no reinstall.

## Why a symlink instead of a copy

A copy means every edit needs a manual sync step (edit → copy →
commit). With a symlink, `~/.claude/CLAUDE.md` *is* the repo file,
so any edit Claude Code or you make goes through git directly.

## Settings merge

`~/.claude/settings.json` is **not** symlinked, because it mixes
repo-portable keys with machine-specific ones (tool paths, plugins,
external hook commands). Instead, `install.sh` merges
`settings.partial.json` into it with `jq -s '.[0] * .[1]'`:

- repo keys win on conflict (re-running enforces them);
- every other key in the user's file is preserved;
- the file is backed up to `settings.json.bak.<timestamp>` before any
  change, and only when the merge actually changes something;
- if `jq` is missing or the existing file is invalid JSON, the merge is
  skipped and the file is left untouched.

To add a setting to the repo-managed set, edit `settings.partial.json`
and re-run `./install.sh` (or `git pull` on other machines and re-run).
Currently managed: `permissions.defaultMode`, `permissions.allow`,
`enabledPlugins`, `effortLevel`, `autoUpdatesChannel`,
`skipDangerousModePermissionPrompt`, `autoCompactEnabled`,
`autoCompactWindow`, `attribution` (empty `commit`/`pr` strings hide the
Co-authored-by / "Generated with Claude Code" trailers on commits and
PRs).

`permissions.allow` is an array, so the repo's list **replaces** any
machine-local allow entries on merge — the repo owns the allowlist.
`enabledPlugins` is an object, so it merges: repo plugins are added and
machine-local plugins are kept.

Note: array-valued keys are **replaced**, not appended, by `*`. That is
why `hooks` is not in this file — it would delete every hook you had
registered for that event. See [Hook merge](#hook-merge).

## Global config merge

Some Claude Code options are **not** settings.json keys. They live in the
global config at `~/.claude.json` (top level), the file `/config` writes
to. Internally the CLI keeps two lists: `GLOBAL_CONFIG_KEYS` (everything
storable there) and a 16-key subset that `settings.json` is allowed to
override. A key in the first list but not the second can *only* be set in
`~/.claude.json` — putting it in `settings.json` silently does nothing.

`claude-json.partial.json` holds those keys, and `install.sh` merges it
into `~/.claude.json` with the same `jq -s '.[0] * .[1]'` + backup dance
as settings.json, plus three extra guards, because that file also holds
auth, onboarding and per-project state:

- **never created** — if `~/.claude.json` is missing, the merge is
  skipped (run `claude` once first) rather than writing a stub;
- **locked** — `install.sh` takes Claude's own mutex first. The CLI locks
  the file with `proper-lockfile`, which is `mkdir("~/.claude.json.lock")`;
  `mkdir` in the script reproduces that atomically, so EEXIST means a
  session is mid-write and the merge is skipped instead of racing it. The
  lock is released via `trap ... EXIT`, and Claude treats any lock older
  than 10s as stale anyway;
- **atomic** — the temp file is created beside the target so the final
  `mv` is a same-filesystem rename.

Currently managed:

| Key | Effect |
|---|---|
| `leftArrowOpensAgents: false` | Stops `←` on an empty prompt from backgrounding the conversation and opening the agents/FleetView list. Default is on; `esc` returns, but the switch is involuntary. Equivalent to `/config` → "← opens agents" → off. |

A running session caches the global config in-process, so the change
takes effect in **newly started sessions**; sessions already open keep the
old behaviour until restarted.

## Adding more files later

Likely future additions, not included yet:

- `keybindings.json`
- `agents/*.md` (subagent definitions)

## Slash commands

| Command | Purpose | Backing playbook |
|---|---|---|
| `/parity-audit` | Codex-style multi-agent audit of a Rust port against an upstream C/C++ reference. Spawns 3–5 read-only sub-agents in parallel, each enumerating one slice of the C surface first and mapping to Rust to find divergences. Produces a permanent inventory doc; commits doc-only before any fixes. | [`audit/c-parity-audit.md`](audit/c-parity-audit.md) |

## Hooks

| Hook | Event | Managed | Purpose |
|---|---|---|---|
| [`hooks/rg-replace-guard.sh`](hooks/rg-replace-guard.sh) | `PreToolUse(Bash)` | yes | Block `rg` invocations that would silently rewrite output through `-r`/`--replace` — a short-flag bundle where `r` is not last (`-rn` parses as `--replace=n`), or an unquoted replacement value. Intentional quoted use passes. |
| [`hooks/no-deferral-guard.py`](hooks/no-deferral-guard.py) | `Stop` | no | Block the response if the last assistant turn defers a discovered defect with phrases like `scope 밖`, `별도 PR`, `out of scope`, `separate PR` and lacks an `UNFIXED:` block. Forces the model to either fix the defect now or properly classify it. Escape hatch: include `[allow-defer]` in your message to pass through. |

Multiple commands under the same `matcher` run together; if any exits
with code 2, Claude is forced to continue with the hook's stderr
reinjected as a new user message.

### Hook merge

A hook marked *managed* above lives in `hooks.partial.json` and is
installed by `install.sh`. Add one there, with `{{REPO}}` standing in
for the clone path:

```json
{
  "Stop": [
    {
      "matcher": "",
      "hooks": [
        { "type": "command", "command": "{{REPO}}/hooks/no-deferral-guard.py" }
      ]
    }
  ]
}
```

The merge is not `.[0] * .[1]` — that replaces arrays, so it would
delete hooks you registered yourself. Instead `install.sh` owns exactly
the entries whose command basename appears in `hooks.partial.json`: it
drops those (which is how a re-run from a moved clone rewrites the path
instead of duplicating the entry), then re-adds them, appending to the
group with the same `matcher` if one exists. Every other entry in your
`hooks` is left alone.

The consequence of that ownership rule: a managed hook script is placed
where `hooks.partial.json` says, so registering it yourself under a
different event or path will be undone on the next install. An unmanaged
hook — `no-deferral-guard.py` today — is yours to register in
`~/.claude/settings.json` by hand and `install.sh` never touches it.
