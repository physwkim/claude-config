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

## Adding more files later

Likely future additions, not included yet:

- `settings.json` (hooks, permissions)
- `keybindings.json`
- `agents/*.md` (subagent definitions)

Each would get its own symlink line in `install.sh`.

## Slash commands

| Command | Purpose | Backing playbook |
|---|---|---|
| `/parity-audit` | Codex-style multi-agent audit of a Rust port against an upstream C/C++ reference. Spawns 3–5 read-only sub-agents in parallel, each enumerating one slice of the C surface first and mapping to Rust to find divergences. Produces a permanent inventory doc; commits doc-only before any fixes. | [`audit/c-parity-audit.md`](audit/c-parity-audit.md) |

## Hooks

| Hook | Event | Purpose |
|---|---|---|
| [`hooks/no-deferral-guard.py`](hooks/no-deferral-guard.py) | `Stop` | Block the response if the last assistant turn defers a discovered defect with phrases like `scope 밖`, `별도 PR`, `out of scope`, `separate PR` and lacks an `UNFIXED:` block. Forces the model to either fix the defect now or properly classify it. Escape hatch: include `[allow-defer]` in your message to pass through. |

Register a hook by adding it to `~/.claude/settings.json` (this file
is not symlinked from the repo today; edit it directly):

```json
{
  "hooks": {
    "Stop": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "/Users/<you>/codes/claude-config/hooks/no-deferral-guard.py"
          }
        ]
      }
    ]
  }
}
```

Multiple commands under the same `matcher` run together; if any exits
with code 2, Claude is forced to continue with the hook's stderr
reinjected as a new user message.
