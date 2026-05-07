# claude-config

Personal Claude Code configuration, versioned so it stays consistent
across machines.

Currently tracks:

- `CLAUDE.md` — global instructions installed at `~/.claude/CLAUDE.md`.

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
- `commands/*.md` (slash commands)
- `agents/*.md` (subagent definitions)

Each would get its own symlink line in `install.sh`.
