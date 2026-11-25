---
name: correct
description: "Find the mistakes agents keep repeating in this repo and make each one impossible: architecture first, then types, then a lint whose error names the fix, then a test, and agent rules last. Prove each check fails on a real past mistake. Use for /correct."
disable-model-invocation: true
---

# Correct

The user keeps correcting agents in this repo for the same mistakes. Change the repo so the next agent can't make them.

Assume every contributor is an agent that sees only the files it opened, copies the nearest example, and takes the shortest path that compiles. Design the repo so a change that looks right from one file is right for the whole repo.

## Find the mistake classes

First, read the recent commits, reverts and review findings, the repo's agent instruction files, the kodex `bug_pattern` and `lesson` entries for the repo, and comments that explain workarounds. Group the mistakes into classes. A class counts once it has happened twice.

## Fix each class at the highest level that works

1. **Eliminate it with architecture.** Give each piece of state one owner and each task one supported way. Hide internals so the wrong import fails (in Rust, `pub(crate)`, a private module, or a sealed trait). Replace hand-synced lists with one source of truth. Delete old ways and dead code an agent would copy.
2. **Enforce it with types so the bad state can't be written.** If bad code still compiles, add a lint or CI check (clippy configuration, a dylint, or a script) whose error names the file, type, or function to use instead. If the pattern is already common, fail only when a change adds more.
3. **Test the behavior.** Fix or delete any test that still passes when the behavior it checks breaks, or that fails when only the internals change.
4. **Write agent rules last, only for judgment calls.** Nothing fails when an agent skips them.

## Fix and prove

Then fix the most frequent classes now, one commit each. The headline names the check. The body names the mistake and a past commit the check would have caught. Prove each new check fails on that real past mistake, by replaying it in a scratch tree. Run the same command locally and in CI. An exception goes on the offending line with its reason, and only with the user's sign-off. Never silence a check crate-wide.

## No rule table

The check is the record, and its error message states the rule. When the user corrects you and an agent rule already covers the mistake but nothing enforces it, that's a repeat, so fix it at the highest level in the same change. Delete an agent rule once a check makes its mistake impossible.

**Reply:** each class with its evidence, the level you picked, and why a higher level didn't work.
