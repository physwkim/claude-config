# C-parity audit (Codex-style)

A reusable methodology for auditing a Rust port against an upstream C
(or C++) reference, distilled from the 2026-05-18 `epics-ca-rs` ↔
`epics-base` audit. Use this when the Rust port's behaviour needs to
match a long-lived C reference byte-for-byte and there is a real
risk that an earlier "review round" missed entire surfaces.

## When to use

- Porting a C/C++ codebase to Rust and the port has had multiple
  hand-driven review rounds without producing a stable inventory of
  divergences.
- A previous reviewer (or you) found 1–2 wire / behaviour mismatches
  and you suspect the same defect class lives elsewhere unfound.
- You have access to the reference source tree on disk, the Rust
  port on disk, and the discipline to rebuild the audit from the
  C side every iteration.

If the port is well-isolated (no shared wire protocol, no concurrent
clients depending on byte-exact reply shape), the lighter
"variant-driven review" in the global `CLAUDE.md` is usually enough.

## The five methodology principles

Each is a correction to a specific failure mode observed in
"normal" Rust-side review rounds.

### 1. Direction: C → Rust, not Rust → C

A Rust-side review only sees what is *in* the port. It cannot find
**missing call sites** (silent failures, unimplemented paths,
admission failures that route through the wrong primitive). It also
cannot detect cases where the Rust code reads as "matches C" but
emits a different wire shape.

**Method:** enumerate the C function surface first. For each C
function in scope, write down:

- The wire frame(s) it emits or parses (opcode, header field
  semantics, payload shape, extended-form trigger).
- The state-model side-effects (cache flips, event-queue mutation,
  callback fan-out).
- The downstream call graph it depends on (jump tables, dispatch
  arrays, special-field callbacks).

Then map each entry to its Rust equivalent and look for
divergences.

### 2. Negative-space exploration

Bugs whose signature is "C has this, Rust has nothing here" are
invisible to `rg` on the Rust side. Look for:

- **Silent failures** — C calls `send_err`, Rust drops on the floor.
- **Missing exception routing** — C has a jump table for op-specific
  exception handling, Rust only fires the global hook.
- **Missing local-only gate** — C applies an admission gate at every
  entry point, Rust applies it at one.
- **Cached-state staleness** — C uses the cached state for the local
  reject; Rust delegates to a server round-trip.
- **Missing structural transitions** — C has a state machine entry
  that Rust skips entirely (e.g. unresponsive → notify-all-IOs).

Concrete exemplars from the worked example (EPICS CA): R2-14
(`CA_PROTO_WRITE` silent put failures), R2-25 (missing
`CLEAR_CHANNEL` on unknown CREATE_CHAN response), R2-36 (admission
failure uses cmd_error not ca_error), R2-37 (subscriptions miss
ECA_DISCONN fan-out).

### 3. Wire-byte parity, not semantic parity

"ECA status matches" or "the effect is the same" is not enough.
Check:

- `m_count` exact value (not just "non-zero"). Extended-form
  requests must round-trip through the extended-annex emit path,
  not get truncated to the 16-bit field.
- `m_cid` slot semantics per opcode. The same slot is "channel
  CID" for one opcode, "SID" for another, "ECA status" for a
  third. Picking the wrong one produces a wire frame that decodes
  but with wrong fields.
- Status carried in `m_cid` vs `m_available` per command.
- Payload size / shape / alignment.
- Header echo extended-form annex presence.

If the port has a comment "matches C foo:NN", open `foo:NN` and
verify; do not trust the comment.

### 4. Test skepticism

The R2-6 finding in the EPICS audit had a regression test asserting
the WRONG C behaviour for months. The test was green, the comment
said "matches C `read_action`", and both were wrong. The reference
was a different function (`read_notify_action`) with different
semantics, and nobody opened the cited line.

**Rule:** when a regression test cites "matches C `XXX:YY`", open
`XXX:YY` directly and verify. Treat the test as evidence the
*reviewer* believed the behaviour; treat the C line as evidence of
the actual C behaviour. They are not the same.

### 5. Permanent inventory

A doc-driven inventory survives across review rounds and across
agents. Without it, every round starts from a blank slate and
re-finds the same five things while missing the next ten.

**Method:** maintain `doc/c-parity-review-YYYY-MM-DD.md` in the
port. Append R-N findings as you discover them. Every review
round, hand the doc to the next agent so they avoid duplicates
and build on the inventory.

The 4-field template:

```
### R2-N: <one-line title>

Severity: High|Medium|Low

Rust: `<file:line>` — <concrete code / behaviour>.

C reference: `<file:line>` — <the C contract>.

Impact: <what wire frame / state / observer behaviour differs>.
```

Each field is mandatory and concrete. The `Rust:` and `C reference:`
fields must be file-line cited; "behaviour" is not enough.

## Workflow

Run the audit in three phases. Each phase commits work that the
next phase builds on.

### Phase 1 — prepare

Before spawning audit agents:

1. **Locate the reference source on disk** and confirm the version.
   Audit findings are invalid if the agent quotes a different
   revision than the port targets.
2. **Read or seed the inventory doc.** If
   `doc/c-parity-review-YYYY-MM-DD.md` doesn't exist, create it
   with sections `## Open Findings` / `## Cleared During Review` /
   `## Review Log`.
3. **Pick the category split.** 3–5 parallel agents is the
   sweet spot. Categories should partition the C surface so each
   agent has a clean assignment with minimal overlap. Worked
   example used four:
   - Client wire / circuit lifecycle (libca tcpiiu/cac/udpiiu/nciu)
   - Server protocol surface (rsrv non-RWE opcodes)
   - Access security / ACF
   - Beacon / repeater / discovery

### Phase 2 — spawn agents

Spawn N general-purpose agents in parallel, one per category. Each
agent receives the same prompt template (below) with category-
specific scope filled in. Their output is a list of R-N findings
in the 4-field format.

**Critical:** every agent prompt must include:

- The path to the existing doc inventory so it does NOT re-report
  findings.
- An explicit number range to start from (e.g. "R2-37+" if the
  inventory ends at R2-36; or category-offset numbers like
  "R2-50+" to avoid sibling-agent collisions).
- "Read-only audit — no source edits."
- The 4-field output format.

### Phase 3 — consolidate

After all agents return:

1. **Renumber to a single contiguous range.** Agents may have
   collided on numbers; assign R-N sequentially in the doc.
2. **Append the consolidated findings to the doc** under
   `## Open Findings`.
3. **Add a Review Log entry** summarising the round + theme
   summary (e.g. "27 findings; theme is disconnect lifecycle +
   env-var parser divergence + multicast scoping").
4. **Commit the doc as its own doc-only commit** before any fixes.
   This way the inventory is preserved even if you abandon the
   fix work midway.
5. **Fix in subsequent commits**, batched by category, marking
   each finding `cleared` in the doc as the fix lands.

## Agent prompt template

```
You are running a Codex-style C-parity audit on `<PORT_PATH>`
against `<REFERENCE_PATH>`.

Direction: C → Rust. Enumerate the C surface first; for each C
function, identify the wire frames it emits or parses and the state
model it touches; then map to the Rust equivalent and find
divergences. The port author already addressed N findings (R2-1..N
in `<INVENTORY_DOC_PATH>`); your job is to find R2-(N+1)+.

Scope (your category): <CATEGORY_NAME>

- C surface to enumerate:
  <BULLET LIST OF C FILES / FUNCTIONS / CONCEPTS IN THIS CATEGORY>
- Rust map: <BULLET LIST OF RUST FILES / MODULES IN THIS CATEGORY>

Codex methodology (strict):

1. C call graph, not isolated bodies. Follow who-calls-what; routing
   tables; jump-table dispatch. Skip this and you miss the SID/CID
   class of bugs.
2. Negative space. Bugs that present as "C has this path, Rust has
   no call site." Examples: missing exception routing, missing
   late-frame cleanup, missing state transition, silent failure,
   missing local-only gate, missing structural transition.
3. Wire-byte parity, not just semantic parity. Count field exact
   value (not just "non-zero"); extended-form annex presence;
   m_cid slot meaning per opcode (CID vs SID vs ECA); status-in-cid
   vs status-in-available; payload size/shape; padding/alignment.
4. Test skepticism. If Rust has a regression test that says
   "matches C XXX:YY", open `XXX:YY` directly and verify. Tests
   asserting the wrong reference behaviour have shipped to
   production in this codebase before; treat the test as evidence
   the reviewer believed it, not evidence the C is what they said.
5. Already-covered findings: R2-1..N in the doc. DO NOT re-report.
   Find NEW divergences only.

Output: list R2-N findings in this exact 4-field template, N
starting at <START_NUMBER>:

### R2-N: <one-line title>

Severity: High|Medium|Low

Rust: `<file:line>` — <concrete code excerpt or behaviour>.

C reference: `<file:line>` — <the C contract>.

Impact: <what wire frame / state / observer behaviour differs>.

Keep findings concrete and citation-anchored. Aim 3-8 findings.
Report 0 only if you are confident the surface is fully covered
(do not pad). Return all findings as plain markdown in your
response — the parent will consolidate into the doc.

Do NOT modify any source files; this is a read-only audit.
Use `rg` / `Read` extensively.
```

## Worked example: EPICS CA (2026-05-18)

The audit that motivated this playbook:

- **Port:** `crates/epics-ca-rs` (Rust port of EPICS Channel Access
  client + server).
- **Reference:** `epics-base/modules/{ca/src/client,database/src/ioc/{rsrv,as,db}}`.
- **Prior state:** 7 review rounds had landed; ~18 wire divergences
  closed.
- **R2 audit result:** 4 sub-agents in parallel produced **27
  additional findings** in one session. Theme distribution:
  disconnect lifecycle fan-out missing (4), TCP dispatcher
  misclassifying known opcodes (1), env-var parser divergence (4),
  multicast/beacon scoping (2), per-circuit accounting (3), wire-
  byte shape (8), state-model gap (5).
- **Trigger:** the 27 findings were directly attributable to
  applying principles 1+2 (C → Rust direction + negative-space
  exploration). Prior Rust-side rounds had grepped the port and
  found nothing further to fix.

Inventory doc preserved at `crates/epics-ca-rs/doc/c-parity-review-2026-05-18.md`.

## Common pitfalls

- **Spawning agents without the inventory** — they re-find the
  same things and waste tokens.
- **Letting the agent number itself from `R2-1`** — collisions
  on consolidation. Always give an explicit start number.
- **Skipping the "category split" step** — one agent covering
  the whole surface will surface only the tip; structural sweeps
  need scope discipline.
- **Treating "compiles + tests pass" as audit success** — the
  audit's purpose is to find what tests don't cover.
- **Fixing during the audit phase** — interleaving slows everyone
  down and risks breaking the inventory mid-round.

## See also

`port-translation-lessons.md` covers:

- What this audit cannot find (reference-side bugs, shared
  wrong-direction errors, historical compat quirks).
- How to classify findings by independence from the reference
  for honest triage and reporting.
- The structural vs methodology split (which findings are
  irreducible language-gap; which are avoidable with front-load
  investment).
- Front-load methodologies (wire golden tests, interop CI,
  malformed-peer fuzzer, throw-site enumeration) and which
  finding classes they catch.

Read it before reporting round results to the user; "27 findings,
all closed" without the classification is a misleading status.

## Anti-pattern: the seven-rounds-of-reviewers smell

If you've run 5+ "review rounds" using Rust-side methodology
(spawning reviewer agents on a git diff, asking "is this code C-
faithful?"), and each round finds 0–2 things, that is **not**
evidence that the port is parity-clean. It is evidence that the
methodology is the wrong shape for this codebase. Switch to this
playbook.
