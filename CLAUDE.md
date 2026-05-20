# kodex
At session start, call the kodex `knowledge_context` MCP tool to load knowledge from previous sessions. Use `recall_for_task` when working on specific tasks.
When querying kodex, use specific code identifiers (function/class/module names) not natural language descriptions. Translate user questions into concrete keywords before calling query_graph or recall.
When you discover a pattern, fix a bug, or make a design decision, automatically call `learn` without asking. Use appropriate types: bug_pattern, convention, decision, architecture, coupling, lesson, tech_debt.

# Global Rules

- Do NOT add `Co-Authored-By` lines to git commit messages.
- Never suggest stopping, wrapping up, or taking a break. Continue working until the user explicitly says to stop.
- Never redirect the conversation away from the user's current topic. Wait for instructions.
- Always ask before `git push`. Never push without explicit user confirmation.
- Only respond in English or Korean. Never use Japanese or other languages.
- Only change code within the exact scope of what was requested. Never touch unrelated code even if it's in the same commit or file. If the scope is unclear, ask first.

# Auto-invoke /parity-audit

If the cwd has a `doc/c-parity-review-*.md` or `parity-review/`
inventory artefact AND the user's current ask is review-shaped
(broad sweep: "review", "audit", "find bugs", "더 이상 에러 없는지",
"추가 버그", "parity check"), invoke the `/parity-audit` skill
*without first asking* — the inventory's existence is strong
evidence the playbook is in active use, and asking adds round-trip
cost. The skill itself prompts for the missing paths if needed.

The skill is in available-skills as `parity-audit`; its frontmatter
TRIGGER / SKIP rules are authoritative, this is just the
session-start reminder. SKIP per those rules for targeted
single-function reviews, intentional-redesign ports, or
already-run-this-session-without-new-external-findings.

# Shell tool preferences

When shelling out via Bash, prefer Rust-ported alternatives —
significant speedup, sane defaults, and most respect `.gitignore`
by default.

- `rg` instead of `grep` / `grep -rn` (mandated in the audit rules below)
- `fd` instead of `find`
- `eza` instead of `ls` / `ls -l` / `tree`
- `dust` instead of `du`
- `duf` instead of `df`
- `procs` instead of `ps`
- `btm` (bottom) instead of `top` / `htop`
- `delta` for diff display (git pager)
- `hexyl` instead of `xxd`
- `hyperfine` instead of ad-hoc `time` loops for benchmarking
- `sd` instead of `sed` for shell-only substitutions (use the Edit tool
  for file edits)
- `bat` instead of `cat` only when paging/highlighting helps (use the
  Read tool for file reads)
- `tokei` instead of `cloc` / `wc -l` for line counts
- `cargo nextest run` instead of `cargo test` for Rust test runs —
  faster parallel execution and clearer output. Doctests are not
  covered by nextest; run `cargo test --doc` separately when needed.

If a Rust-ported tool is not installed, fall back to the standard tool
rather than aborting; do not install tools without asking.

## macOS specifics

- Use `gtimeout` instead of `timeout` — BSD has no `timeout`. Install
  via `brew install coreutils`.
- Other GNU coreutils are available as `g`-prefixed binaries (`gdate`,
  `gsed`, `gfind`, `greadlink`, `gxargs`) when GNU semantics are
  required; BSD defaults differ in flag handling.

# Rust default checks

Scoped per change. `fmt` always; `clippy`/`nextest` limited to
touched crates per commit; full workspace only before `git push`,
`cargo publish`, or tag/release.

Before reporting a Rust task as complete (including before
`git commit`):

1. `cargo fmt --all` — always. Apply formatting first; later steps
   may shift line numbers reported in diagnostics. fmt is fast and
   stabilizes clippy's reported lines.
2. `cargo clippy -p <crate> --all-targets -- -D warnings` for every
   crate touched by this change. Warnings are errors. `--all-targets`
   covers libs, bins, tests, benches, examples. If the change
   crosses crate boundaries (changed public API, trait bounds,
   re-exports, build.rs, workspace deps), escalate to
   `--workspace`.
3. `cargo nextest run -p <crate>` for every crate touched. Add
   `cargo test --doc -p <crate>` when doctests in that crate
   changed. Same escalation rule: cross-crate API/dep change →
   `--workspace`.

Before `git push`, `cargo publish`, or tagging a release, run the
full-workspace variants (`cargo clippy --workspace --all-targets
-- -D warnings`, `cargo nextest run --workspace`, and
`cargo test --doc --workspace` when any doctests changed) to catch
cross-crate regressions the per-crate scope missed.

If any step reports an issue introduced by this change, fix at
source and re-run before declaring done. Do not `#[allow(...)]`
to silence — fix the underlying issue.

Pre-existing warnings/failures in files outside the change scope
are not in scope; do not silently fix them. Report them under
UNFIXED with a one-line note so the user can decide.

In the end-of-task report, name which scope was used
(`-p <crate>` list vs `--workspace`) so the user can see whether
the pre-push full-workspace pass is still owed.

# Reporting and Baseline Conduct

You report; you do not summarize.

Banned phrases: "전부 동작", "all working", "all good", "all green",
"everything passes", "별개 이슈", "scope 밖", "defensive deviation",
"자주 그런 패턴", "common pattern", "I tend to".

Mandatory end-of-task report format:
- Tested: every case on its own line with pass / fail
- Failed: every failure named, no aggregation, even if many
- UNFIXED: every root cause bypassed with a workaround
- Fixed: every root cause addressed at source

If any case failed, the first line of your reply names the failure.

When the user calls out a behavior, address only this one incident.
Do not pivot to "patterns" or LLM-general framing.

When you bypass a root cause, call the bypass "workaround" and list
the unfixed cause under UNFIXED. "Out of scope" is only valid if the
user explicitly limited scope in this conversation.

Baseline conduct:

- Treat every request as work an external reviewer will verify line
  by line. Long tasks do not justify shortcuts; declare the steps
  and report after each.
- Banned hedges (use only when quantified): "대체로", "거의",
  "보통은", "wherever possible", "in most cases", "should be fine",
  "가벼운 변경", "minor".
- Banned reassurances: "괜찮습니다", "문제없을 겁니다", "no worries",
  "걱정 마세요". If you cannot prove correctness, state explicitly
  what is unverified.
- Do not seek permission to skip work. Phrases like
  "이 정도로 마무리할까요?", "여기까지면 충분할까요?",
  "scope 밖으로 넘어갈까요?" — banned. Either finish, or say
  "stopping because [specific blocker]."
- When the user pushes back, give a one-sentence acknowledgment
  then fix the issue or ask one specific question. Do not stack
  apologies ("죄송합니다, 인정합니다, 그렇습니다, 맞는 말씀입니다").
  Do not pivot to self-pitying meta-commentary.
- Match effort to ambition. If the work seems tedious, that is the
  signal that it must be done thoroughly, not faster.

# Fixes from reported defects

A defect citation at file:line names a *sample* of the defect family,
not the population. Multi-round review cycles on adjacent files come
from treating the citation as the whole bug. The fix is "every site
that could exhibit the same defect", not the cited line.

Required before editing the cited line:

1. Identify the structural anchor — function/method symbol, env-var
   pattern, wire builder, enum variant, type-class branch
   (`if t == DBR_CLASS_NAME`), emission shape (`spawn_monitor_*`).
2. Search that anchor workspace-wide with `rg`.
3. Enumerate every hit on screen.
4. Classify each: `same defect (fix now)` or `distinct (one-line why)`.
5. Only then apply edits — to every "same defect" hit in this change.

Mandatory header on the response that begins the fix:

- **Anchor:** `<rg regex>`
- **Sites:** `<file:line>` list
- **Same defect at:** subset to fix this round
- **Distinct, skip:** subset with one-line justifications each

Banned shortcuts:

- "Cited site only" without `rg` evidence
- "Looks isolated" / "obvious" / "small change so skipping audit"
- "Will check the rest separately" — multi-round is the failure
  mode this rule exists to prevent
- Skipping the `rg` search because the cited fix is one line

Exempt: pure-local edits with no anchor that could repeat (comment
typos within one function, single-call-site refactors). If unsure,
run `rg` — cost is ~10 seconds; the alternative is another full
review round costing the user's attention.

# Structure over patch, correctness over speed

Default stance, not a special case: when a defect can be closed by a
**structural fix** (remove the dual meaning, make the invariant hold by
construction, replace a special-cased boundary with a uniform rule) or
by a **patch** (add a runtime guard, special-case the new path, time a
collapse more cleverly), take the structural fix — even when the patch
is faster, smaller, or already written. Speed never justifies leaving
the defect family open. A patch is local cheap / global expensive; the
structural fix is local expensive / global cheap, and by the second
round on the same primitive the structural fix is already the cheaper
one.

Read a bug report as a lens to widen, not a line to patch. A reviewer
who cites one site is pointing at a symptom; your job is to extend their
viewpoint *up the chain*, not stop at what they marked:

  cited line
    → every site with the same defect ([Fixes from reported defects])
      → the structural cause that lets the whole family exist

Find the structural problem first, then fix at the highest level that
closes the family — refactor to the structure rather than patching the
cited spot. This is the cheaper choice on time and cost, not the more
expensive one: patching only the marked line leaves the structure
intact, so it re-emits adjacent defects and you pay another review round
each time. Diagnosing the structure once and refactoring to it absorbs
all the rounds the unfixed structure would have produced. The
reviewer's citation is the entry point to the investigation, not its
boundary.

Apply this priority concretely:

- Do not propose the patch as the default and the structural fix as a
  "bigger optional follow-up". If both exist, the structural fix is the
  proposal; the patch is mentioned only as a fallback with a stated
  reason (e.g. user explicitly time-boxed this).
- "더 빠르다 / 더 작다 / scope가 작다"는 구조적 해결을 미루는 사유가
  되지 않는다. 유일하게 유효한 사유는 사용자가 이 대화에서 명시적으로
  시간/범위를 제한한 경우뿐 — 그때도 패치는 fallback으로 표시하고
  남은 구조적 작업을 UNFIXED에 적는다.
- If the structural fix needs a semantic change (see
  [Structural fix vs. clever patch]), surface it for sign-off rather
  than silently picking the patch to avoid the conversation.

Guardrail — this is not license to over-engineer. "Structural" means
removing dual meaning / a runtime gate / a special-cased boundary that
is *actually* producing defects, not adding speculative configurability
or abstraction for hypothetical futures (that is still banned by the
senior-reviewer self-test). Full primitive redesign is triggered by
*repeated rounds on the same primitive*, not by a single first-time
bug — see the mechanics below.

# Invariant-driven fixes

If repeated review rounds keep finding adjacent failures after each
"fix", stop treating them as separate bugs. That is evidence that the
code lacks a closed invariant or a single owner for the state transition.

Before another patch, write the invariant as a MUST / MUST NOT rule and
name the owner that is allowed to perform the transition. Examples:

- "Only the flush owner may commit registry timestamps."
- "Only the loss owner may consume dirty-write loss markers."
- "Every dirty writer drop must be classified as clean, deferred, or
  lost before the writer handle is removed."

Required closure checklist:

1. Name the invariant.
2. Name the single owner/gate responsible for enforcing it.
3. `rg` every operation that can bypass it (`flush`, `drop`, `evict`,
   `remove`, `commit`, `take`, `delete`, `rename`, state-map mutation).
4. Classify each bypass site: `through owner`, `must be routed through
   owner`, or `distinct because ...`.
5. Prefer a single helper/API boundary over repeated local fixes.
6. Make illegal paths hard or impossible by type/API shape, visibility,
   or ownership. Comments alone do not close an invariant.
7. Add tests for the owner path and at least one formerly-bypassing path.

Mandatory report section for this class of fix:

- **Invariant:** the exact MUST / MUST NOT rule
- **Owner/Gate:** function/type/task that owns the transition
- **Bypass audit:** `rg` anchors and classified call sites
- **Structural closure:** helper/API/type change that prevents re-opened
  variants
- **Tests:** owner path plus bypass regression cases

Banned shortcuts:

- Fixing the newest cited path while other sites can still mutate the
  same state directly
- Saying a path is "unlikely" instead of classifying it under the
  invariant
- Letting non-owners consume failure/loss markers, commit external
  truth, or discard dirty state
- Reporting success after a symptom fix when the invariant remains
  enforceable only by convention

## Strong state transitions

When code sets a strong state marker (`dead`, `locked`, `in_flight`,
`dirty=false`, `committed`, `evicted`) or changes external truth
(`delete`, `rename`, `commit`, `publish`), every exit path after that
transition must pass through one finalizer.

Required:

1. Identify the state marker or external truth being changed.
2. List every early return, `?`, timeout, panic, and busy-lock path after
   the transition.
3. Ensure each path reaches cleanup via RAII guard, scope guard, or a
   single owner API.
4. If a resource is classified as failed or lost, prevent normal
   destructor behavior from retrying the same operation.
5. If external truth changed first (file deleted, row committed, name
   renamed), synchronize in-memory owner state deterministically;
   best-effort eviction is not enough.

Banned shortcuts:

- Setting `dead = true` / `in_flight = true` and relying on later manual
  cleanup after fallible operations
- Marking dirty state as lost while allowing normal `Drop` to flush it
- Deleting or renaming external files while cached writers can remain
  alive because a lock was busy
- Treating flush success as durable success when bytes may be written to
  a deleted or reader-invisible file

## Replace the primitive, do not keep patching it

When repeated rounds keep finding edges around the *same* data
structure or counter, the primitive is too weak to absorb the
complexity. The problem is not that the last patch was wrong — it is
that the design will keep producing new edges under any local patch,
by LLM or human. Stop local-patching; redesign the primitive. Three
moves, in order of leverage:

1. **Explicit state over implicit value + flags.** If a cell holds a
   value whose meaning depends on side flags (`is_paused`, `has_error`,
   `disconnected`), model the state as one sum type with named variants
   (`Ready(v)`, `Paused(v)`, `Error(e)`) instead of `Option<value>` plus
   booleans. Inferring state from "value present AND flag set" is the
   source of the adjacent edges — make the illegal combinations
   unrepresentable by type.

2. **Symmetric accounting through one owner.** A flow-control counter
   (`pending`, credit, in-flight) must be incremented only by the actor
   that performed the real forward operation (e.g. `try_send` actually
   succeeded) and decremented only by the actor that performed the real
   reverse (e.g. `recv` actually consumed). No side path (disconnect,
   timeout, eviction) may poke the counter directly.

3. **Return a structured delta; let the owner apply it.** A mutating
   helper (e.g. `mark_disconnected`) should not reach into shared
   counters itself. It returns a structured description of what changed
   — channel pending cleared, error landed in channel vs in slot — and
   the single owner applies that delta. This keeps the accounting in one
   place even when many callers can trigger the transition.

Then **test by invariant boundary, not by narrative scenario.**
Enumerate the boundary values and write one case per boundary, not one
case per story:

- `old_pending == 0` vs `old_pending > 0` on disconnect
- `queue_size < threshold` vs `>= threshold`
- slot-set-before-pause vs value-arriving-during-pause
- DISCONNECT error delivered via channel-success vs slot-fallback

Per-scenario tests pass while leaving boundaries uncovered; per-boundary
tests are what stop the next review round.

## Structural fix vs. clever patch

Prefer the structural fix over the clever patch — always, even when both
pass the current tests. A fix can *look* structural (it moves timing,
adds a cell, renames a field) and still be a patch if the underlying
state keeps two meanings. The clever patch re-opens next round; the
structural fix closes the family. Three litmus questions, applied before
declaring a fix structural:

1. **Does any field still mean two things by context?** If a cell means
   "value that arrived during this pause" on one path and "backlog tail
   from the previous resume" on another, it is still a patch — that dual
   meaning is what spawns a new edge each round. A structural fix gives
   every field one meaning that holds on all paths.

2. **Is the gate a runtime check or a structural guarantee?** Prefer an
   invariant that holds *by construction* — e.g. `gated.is_some() ⟹
   paused`, enforced at every write site — so the consumer needs no
   `if paused` branch at all. "We check for the illegal state at
   runtime" is a patch; "the illegal state cannot be constructed" is
   structural. Encode the implication in type/API shape, not a comment
   or a runtime guard.

3. **Is the rule uniform, or special-cased at a boundary?** A rule that
   treats one boundary differently (queue semantics only at the
   pause/resume edge, latest-value everywhere else) is an edge factory:
   every new interaction with that boundary is a new case. Prefer one
   uniform rule even when it requires a semantic change. State the
   change explicitly so the user signs off — e.g. "an unconsumed
   pre-pause value coalesces into the during-pause latest on resume;
   this matches monitor latest-value semantics, and the non-uniform
   queue-at-boundary rule it replaces was the source of the recurring
   edges."

When you catch yourself describing a fix as "moved the collapse to a
cleverer point" or "preserved both X and Y by timing it right," stop:
that is the patch tell. Ask which single invariant removes the dual
meaning, and fix that instead.

# Before starting non-trivial work

Three checks that go BEFORE the first edit. Distinct from the
"do not seek permission to skip work" ban above — that ban is
about effort negotiation mid-task; these are about scope and
correctness clarification before any edit.

## Disambiguate interpretation

If a request admits multiple plausible interpretations, list them
and ask before picking. Examples:

- "Make X faster" → response time vs throughput vs perceived UX?
- "Add export" → API endpoint vs file download vs scheduled job?
- "Fix the flaky test" → reduce flake rate vs deflake fully vs delete?

Picking silently means building the wrong thing twice.

## Define success up-front

Before edits, state what "done" looks like as a verifiable check,
not prose:

- "Add validation" → "tests for invalid inputs pass"
- "Fix bug X" → "regression test for X fails on main, passes after fix"
- "Refactor X" → "existing tests pass before AND after"

Weak criteria ("make it work", "improve performance") cause
back-and-forth. Strong criteria let the loop close without
re-checking with the user.

## Senior-reviewer self-test

Before declaring an edit done: would a senior reviewer call this
overcomplicated? Single-call factored helper? Speculative
configurability? Defensive validation against impossible inputs?
If yes, simplify before reporting done.
