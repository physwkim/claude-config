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
