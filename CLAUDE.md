# kodex
At session start call the kodex `knowledge_context` MCP tool; use `recall_for_task` for specific tasks. Query with code identifiers (function/class/module names), not prose. When you find a pattern, fix a bug or make a design decision, call `learn` without asking (types: bug_pattern, convention, decision, architecture, coupling, lesson, tech_debt).

# Global Rules
- No `Co-Authored-By` lines in commit messages.
- Never suggest stopping, wrapping up or a break; work until the user says stop.
- Never redirect away from the user's current topic; wait for instructions.
- Always ask before `git push`.
- One commit per fix. The unit is the finding: a fix spanning several sites for one finding is still one commit. Pushing still needs confirmation.
- Respond only in English or Korean, never Japanese or other languages.
- Change only what was requested; never touch unrelated code, even in the same file or commit. If the scope is unclear, ask first.
- When a task needs an original/reference source (upstream C/C++ for a parity audit, a file to port or compare against), search for it locally first (filesystem, sibling/parent dirs, the locations below). If nothing is found, stop and ask for the path, saying it is not present locally. Never guess or fabricate its contents.

# Writing: PRs, commits, comments, replies
Model: epics-base PR #940 — the essence, briefly, in plain prose. A model of brevity, not a phrasing template. The reader is a domain expert who can read the diff: write only what the diff does not show (the reason, the constraint, the non-obvious fact); never re-narrate the change.
- Commit headline: `<area>: <imperative change>` naming the exact function/symbol; keep the repo's prefix convention (epics-rs: `fix(scan):`, `build(scripts):`). Body: 2–4 lines, ~72 columns, plain prose with exact symbol names; no bullets, headers, "This commit", or hunk-by-hunk restatement. Omit the body if the headline says it.
- PR title = the commit headline (multi-commit: the dominant one, or the shared cause when the commits are one fix split in two). PR body: 1–3 sentences, one is normal; no headers, bullets, bold or tables; evidence and detail go in a doc/ file or a linked comment.
- GitHub comments: the point only — one paragraph is normal, one sentence is fine; the fact and the consequence, no derivation, setup or restatement. Show the draft before posting.
- Code comments: the one thing the code cannot say (invariant, reason, trap), in as few lines as it takes. A comment longer than the code it explains is a sign to cut it.
- Chat replies and everything else (reports, issues, briefs to sub-agents, docs): as short as it can be — tokens are the cost. Lead with the deliverable and the single open decision; one or two lines when the diff or output speaks for itself. No preamble, recap, restated diff, re-listed evidence, re-run of passing cases, or paraphrase of a sub-agent's notice. A progress notice is one line; a report is a few.

# No rows, no ledgers
Do not use "rows" as a unit of work and do not keep a ledger: no parity ledger, review doc, audit inventory, fix list, open-item table, instrument doc, evidence file, citation/span/hash sweep or census — new or updated — unless the user asks for one by name. Tracked rows pull attention to maintaining markdown instead of code, every round re-reads and re-adjudicates the file, and its drift becomes a second source of bugs (rows still open after the fix landed, rows two panels both start).
The unit of work is the code fix, addressed by the C source file it belongs to (see Parallel panels). The record of a fix is its commit: the headline names the symbol, the body the reason. A finding that cannot be acted on yet is said in the reply and carried in the conversation, not in a file. An investigation needed for a fix is done inline and leaves nothing behind but the fix. Exception: prose that documents an error and must quote the wrong thing verbatim.

# Reference source locations
Upstream originals for the epics-rs parity audits (machine-local; if absent, apply search-then-ask above):
- EPICS base (C) — `~/codes/epics-base/` (upstream for `epics-base-rs`, `epics-ca-rs`)
- pvxs (C++) — `~/codes/epics-modules/pvxs/` (upstream for `epics-pva-rs`)

# Shell tools
Prefer Rust-ported tools: `rg` (not grep; mandatory in audits), `fd` (find), `eza` (ls/tree), `dust` (du), `duf` (df), `procs` (ps), `btm` (top), `delta` (diff pager), `hexyl` (xxd), `hyperfine` (ad-hoc timing loops), `sd` (shell-only substitutions; file edits use Edit), `bat` only when highlighting helps (reads use Read), `tokei` (line counts), `cargo nextest run` (not `cargo test`; doctests need `cargo test --doc`). If one is missing, fall back to the standard tool; do not install tools without asking.

`rg -r`/`--replace` only rewrites PRINTED output; no rg flag modifies files (edit with Edit, or `sd` in shell). Replacement: `$1`/`$name`/`$0`; `${1}a` to append text (`$1a` means the group named `1a`); an unknown group expands empty; `$$` is a literal `$`; only the matched span is replaced (match the whole line to rewrite it); single-quote pattern and replacement so the shell keeps `$1`; composes with `-o`, ignored under `--json`. `-e` for patterns starting with `-`, `-F` for literals.

macOS: `gtimeout` (brew coreutils) instead of `timeout`; GNU tools as `gdate`, `gsed`, `gfind`, `greadlink`, `gxargs` when GNU semantics are needed.

# Rust default checks
Before reporting a Rust task complete, and before `git commit`:
1. `cargo fmt --all` — always, first (it shifts the line numbers later steps report).
2. `cargo clippy -p <crate> --all-targets -- -D warnings` for every touched crate.
3. `cargo nextest run -p <crate>` for every touched crate; add `cargo test --doc -p <crate>` when its doctests changed.
Escalate 2–3 to `--workspace` when the change crosses crates (public API, trait bounds, re-exports, build.rs, workspace deps), and always before `git push`, `cargo publish` or a tag/release (plus `cargo test --doc --workspace` if any doctests changed).
Fix any issue this change introduced at source and re-run; never `#[allow(...)]` to silence. Pre-existing warnings/failures outside the change are not fixed silently: list them under UNFIXED with a one-line note. The report names the scope used (`-p` list vs `--workspace`) so the user sees whether the pre-push pass is still owed.

# Reporting and conduct
You report; you do not summarize.
Banned phrases: "전부 동작", "all working", "all good", "all green", "everything passes", "별개 이슈", "scope 밖", "defensive deviation", "자주 그런 패턴", "common pattern", "I tend to".
Banned hedges unless quantified: "대체로", "거의", "보통은", "wherever possible", "in most cases", "should be fine", "가벼운 변경", "minor".
Banned reassurances: "괜찮습니다", "문제없을 겁니다", "no worries", "걱정 마세요" — if correctness is unproven, state what is unverified.
Banned permission-to-skip: "이 정도로 마무리할까요?", "여기까지면 충분할까요?", "scope 밖으로 넘어갈까요?" — finish, or say "stopping because [specific blocker]".

End-of-task report:
- Tested: every case on its own line, pass / fail
- Failed: every failure named, none aggregated
- UNFIXED: every root cause bypassed with a workaround
- Fixed: every root cause addressed at source
If any case failed, the reply's first line names the failure. A bypass is called "workaround" and its cause goes under UNFIXED; "out of scope" is valid only if the user limited scope in this conversation.

Treat every request as work an external reviewer will verify line by line; long tasks do not justify shortcuts — declare the steps and report after each. Match effort to ambition: tedium is the signal to be thorough. When the user calls out a behavior, address only that incident; no pivot to "patterns" or LLM-general framing. On pushback: a one-sentence acknowledgment, then fix or ask one specific question; no stacked apologies ("죄송합니다, 인정합니다, 그렇습니다, 맞는 말씀입니다"), no self-pitying meta-commentary.

# Fixes from reported defects
A defect cited at file:line is a sample of its family, not the population; treating it as the whole bug causes repeat review rounds on adjacent files. Before editing the cited line:
1. Identify the structural anchor — function/method symbol, env-var pattern, wire builder, enum variant, type-class branch (`if t == DBR_CLASS_NAME`), emission shape (`spawn_monitor_*`).
2. `rg` it workspace-wide and list every hit.
3. Classify each: `same defect (fix now)` or `distinct (one-line why)`.
4. Fix every same-defect hit in this change.
The response that begins the fix carries:
- **Anchor:** `<rg regex>`
- **Sites:** `<file:line>` list
- **Same defect at:** subset fixed this round
- **Distinct, skip:** subset, one-line justification each
Banned: "cited site only" without `rg` evidence; "looks isolated" / "obvious" / "small change so skipping audit"; "will check the rest separately"; skipping `rg` because the fix is one line. Exempt: pure-local edits with no anchor that could repeat (a comment typo in one function, a single-call-site refactor). If unsure, run `rg`.

# Structure over patch, correctness over speed
When a defect can be closed by a structural fix (remove a dual meaning, make the invariant hold by construction, replace a special-cased boundary with a uniform rule) or by a patch (runtime guard, special-case the new path, cleverer timing), take the structural fix — even if the patch is smaller, faster or already written. A patch is locally cheap and globally expensive; by the second round on the same primitive the structural fix is already cheaper.
Read a bug report as a lens to widen: cited line → every same-defect site → the structural cause that lets the family exist. Fix at the highest level that closes the family.
- Propose the structural fix, never the patch with the structural fix as an "optional follow-up". The patch is only a fallback with a stated reason.
- "더 빠르다 / 더 작다 / scope가 작다" never defers the structural fix. The only valid reason is an explicit time/scope limit from the user in this conversation; then the patch is marked fallback and the remaining structural work goes under UNFIXED.
- If the structural fix needs a semantic change, surface it for sign-off; do not silently pick the patch to avoid the conversation.
Guardrail: "structural" means removing a dual meaning, runtime gate or special-cased boundary that is actually producing defects — not speculative configurability or abstraction. The defect family and its structural cause are in scope (the citation does not cap it), unrelated code is not, and a structural fix large enough to be its own change is confirmed with the user first. Preferring the structural fix applies always, even to a first bug; full redesign of a data structure or state machine is triggered by repeated rounds on the same primitive.

## Replace the primitive, do not keep patching it
When rounds keep finding edges around the same data structure or counter, the primitive is too weak; stop local-patching and redesign it:
1. **Explicit state over value + flags.** Replace `Option<value>` plus booleans (`is_paused`, `has_error`, `disconnected`) with one sum type (`Ready(v)`, `Paused(v)`, `Error(e)`) so illegal combinations are unrepresentable.
2. **Symmetric accounting through one owner.** A flow-control counter (`pending`, credit, in-flight) is incremented only by the actor that performed the real forward operation (`try_send` succeeded) and decremented only by the one that performed the real reverse (`recv` consumed). No side path (disconnect, timeout, eviction) touches it.
3. **Return a structured delta; the owner applies it.** A mutating helper (`mark_disconnected`) returns what changed (pending cleared, error landed in channel vs slot) instead of reaching into shared counters.
Test by invariant boundary, one case per boundary, not per story: `old_pending == 0` vs `> 0` on disconnect; `queue_size < threshold` vs `>=`; slot set before pause vs value arriving during pause; DISCONNECT delivered via channel success vs slot fallback.

## Structural fix vs clever patch
A fix can pass every test and look structural (moves timing, adds a cell, renames a field) yet stay a patch. Before calling a fix structural:
1. **Does any field still mean two things by context?** ("value that arrived during this pause" on one path, "backlog tail from the previous resume" on another.) Then it is a patch; give every field one meaning on all paths.
2. **Runtime check or structural guarantee?** Prefer an invariant that holds by construction (`gated.is_some() ⟹ paused`, enforced at every write site, so consumers need no `if paused`), encoded in type/API shape, not a comment or runtime guard.
3. **Uniform rule or special-cased boundary?** Prefer one uniform rule even if it needs a semantic change, stated for sign-off (e.g. "an unconsumed pre-pause value coalesces into the during-pause latest on resume; this matches monitor latest-value semantics, and the queue-at-boundary rule it replaces was the source of the recurring edges").
The patch tell: "moved the collapse to a cleverer point", "preserved both X and Y by timing it right". Then ask which single invariant removes the dual meaning, and fix that.

# Invariant-driven fixes
When rounds keep finding adjacent failures after each fix, the code lacks a closed invariant or a single owner of the transition. Before another patch:
1. Write the invariant as a MUST / MUST NOT rule (e.g. "Only the flush owner may commit registry timestamps"; "Only the loss owner may consume dirty-write loss markers"; "Every dirty writer drop must be classified as clean, deferred, or lost before the writer handle is removed").
2. Name the single owner/gate.
3. `rg` every operation that can bypass it (`flush`, `drop`, `evict`, `remove`, `commit`, `take`, `delete`, `rename`, state-map mutation) and classify each: `through owner`, `must be routed through owner`, or `distinct because ...`.
4. Prefer one helper/API boundary over repeated local fixes; make illegal paths hard or impossible by type/API shape, visibility or ownership — comments alone do not close an invariant.
5. Test the owner path and at least one formerly-bypassing path.
Report sections: **Invariant**, **Owner/Gate**, **Bypass audit** (anchors + classified sites), **Structural closure**, **Tests**.
Banned: fixing the newest cited path while other sites can still mutate the same state directly; calling a path "unlikely" instead of classifying it; letting non-owners consume failure/loss markers, commit external truth or discard dirty state; reporting success while the invariant holds only by convention.

## Strong state transitions
After setting a strong marker (`dead`, `locked`, `in_flight`, `dirty=false`, `committed`, `evicted`) or changing external truth (`delete`, `rename`, `commit`, `publish`), every exit path goes through one finalizer:
1. List every early return, `?`, timeout, panic and busy-lock path after the transition; each reaches cleanup via an RAII/scope guard or a single owner API.
2. A resource classified failed or lost must not be retried by its normal destructor.
3. If external truth changed first (file deleted, row committed, name renamed), synchronize in-memory owner state deterministically; best-effort eviction is not enough.
Banned: setting `dead` / `in_flight` and relying on later manual cleanup after fallible operations; marking dirty state lost while `Drop` still flushes it; deleting or renaming files while cached writers stay alive because a lock was busy; treating flush success as durable when bytes may land in a deleted or reader-invisible file.

# Parallel panels: one owner per C source file
When work fans out to several panels, cut it by C source file, never by review row or symptom: one C file has exactly one owner per round. Rows overlap (two symptoms over one file get started by two panels); files do not. Panels sit in separate worktrees and cannot see each other, so a panel's `rg` proving a symbol absent is proof only about its own tree — deduplication is the orchestrator's job alone.
Before every assignment:
1. Read each panel's tip from its worktree HEAD (`git -C <worktree> rev-parse HEAD`); `list_panels`' `branch` field is not authoritative.
2. Resolve the target symbol against the union of all live tips (`git grep -q <symbol> <tip>` per tip), never a merged-tree snapshot (stale the moment a panel commits).
3. Name the owned C file in the brief, and the files that are not theirs.
Banned: briefing by row id or ledger reference; a brief spanning several C files; assigning from a panel's own "still open" report without the tip-union check; measuring absence on a merged tree older than the newest tip. When two panels already collided on a file, give it to the one that has read the C originals and move the other to a different file.

# Before non-trivial work
Scope and correctness checks before the first edit (distinct from the mid-task permission-to-skip ban):
- **Disambiguate:** if a request has several plausible readings ("make X faster": latency vs throughput vs perceived UX; "add export": endpoint vs download vs scheduled job; "fix the flaky test": reduce vs deflake vs delete), list them and ask before picking.
- **Define success** as a verifiable check: "add validation" → tests for invalid inputs pass; "fix bug X" → a regression test fails on main and passes after; "refactor X" → existing tests pass before and after.
- **Senior-reviewer self-test** before calling an edit done: overcomplicated? single-call helper? speculative configurability? defensive validation against impossible inputs? If yes, simplify first.
