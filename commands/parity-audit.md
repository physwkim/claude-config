---
description: |
  Codex-style multi-agent C-parity audit of a Rust port against an
  upstream C/C++ reference. Spawns 3-5 read-only sub-agents in
  parallel, each enumerating one slice of the C surface first and
  mapping to the Rust port to find wire/byte/state divergences.
  Produces a permanent inventory doc; commits doc-only before any
  fixes.

  TRIGGER (auto-invoke, do NOT first ask) when ALL of these hold:
  (1) the cwd is a Rust crate that ports an external C/C++ codebase
  (Cargo.toml present AND companion C reference exists on disk OR
  the workspace already has a `doc/c-parity-review-*.md` /
  `doc/*-parity-*.md` / `parity-review/` inventory artefact); AND
  (2) the user's current ask is a *review*, *audit*, *find bugs*,
  *parity check*, *byte-for-byte*, "더 이상 에러가 없는지 확인",
  "추가 버그 찾아줘", or similar broad sweep. Existence of the
  inventory artefact alone is strong evidence that the playbook
  is in active use; treat it as a hard trigger when paired with
  a review-shaped ask.

  SKIP when: (a) user asks for a *targeted* review of a specific
  function or file (single-scope fix request, not a sweep);
  (b) the port is intentionally a redesign rather than wire-faithful
  (PVA pvxs-port, gRPC reimplementation, etc.); (c) you have
  already run /parity-audit this session and the inventory doc has
  not received new external findings — re-running spends tokens
  without surfacing more.

  When triggered, run the workflow below — do NOT just suggest
  it; invoke it.
---

Run a **Codex-style C-parity audit**: enumerate the C reference
surface first, fan it out to N parallel sub-agents by category,
collect findings into a permanent inventory doc, and produce a
batch of R-N divergence reports without modifying source code.

Full methodology is documented at `~/codes/claude-config/audit/c-parity-audit.md`
(also accessible as the symlinked path under `~/.claude/`). Read
that doc once for the principles; the workflow below is the
execution-time checklist.

## Workflow

### 1. Confirm inputs with the user (use AskUserQuestion)

Ask in one batch:

- **Port path** — the Rust crate(s) to audit (e.g.
  `crates/epics-ca-rs/src`).
- **Reference path** — the C/C++ source tree (e.g.
  `~/codes/epics-base/modules/ca/src/client`).
- **Inventory doc path** — defaults to
  `<port-crate>/doc/c-parity-review-YYYY-MM-DD.md` using today's
  date. If a doc already exists, use it as the baseline.
- **Category split** — 3–5 categories. If the user does not have
  one in mind, propose a split based on the surface (e.g. for
  a wire-protocol port: client wire, server protocol, state/
  access, discovery/transport).

### 2. Verify state before spawning

- Read the inventory doc (if present) and note the highest R-N.
- The next agent batch starts at `R(N+1)`. Each agent gets a
  numbering range carved out by category so they don't collide
  (e.g. category-A: R+1..+15, category-B: R+16..+30, etc.).
- Confirm the C reference exists on disk.

### 3. Spawn agents in parallel

Use the **Agent tool with `subagent_type: general-purpose`**, one
agent per category, **all in a single message** so they run in
parallel. Each agent's prompt MUST include all five Codex
principles verbatim:

1. C call graph, not isolated bodies (follow who-calls-what,
   routing tables, jump-table dispatch).
2. Negative space (silent failures, missing exception routing,
   missing local-only gate, missing state transition).
3. Wire-byte parity, not just semantic parity (count field
   exact value, extended-form annex, m_cid slot semantics per
   opcode, payload shape/alignment).
4. Test skepticism (open every cited "matches C XXX:YY" line
   directly; don't trust comments or green tests).
5. Already-covered findings in the inventory doc — DO NOT
   re-report.

Use the prompt template from
`~/codes/claude-config/audit/c-parity-audit.md` (the "Agent
prompt template" section). Substitute `<PORT_PATH>`,
`<REFERENCE_PATH>`, `<INVENTORY_DOC_PATH>`, `<CATEGORY_NAME>`,
`<C surface ...>`, `<Rust map ...>`, `<START_NUMBER>` per agent.

Each agent must be told: **read-only, no source edits**, output
findings as plain markdown in the 4-field template (R-N title /
Severity / Rust file:line / C reference file:line / Impact).

### 4. Consolidate

Once all agents return:

- Renumber findings sequentially across agents (drop any
  collisions).
- Append them to the inventory doc under `## Open Findings`.
- Add a `## Review Log` entry summarising the round and the
  thematic clusters that emerged (the theme summary often
  itself points at structural gaps).
- **Commit the doc as a doc-only commit BEFORE any fix work.**
  This locks in the inventory regardless of whether the fix
  phase completes.

### 5. Fixes (optional, separate phase)

Only after the audit doc is committed, ask the user whether to
proceed with fixes. If yes, fix in category-batched commits,
marking each finding `cleared` in the doc as it lands. Do not
interleave audit and fix work in the same commit.

## Anti-patterns to refuse

- Spawning agents without handing them the inventory doc (they
  will re-find the same things).
- Letting each agent number from R-1 (collisions on consolidation).
- Skipping the doc-only commit (loses the inventory if fixes are
  abandoned).
- Treating "tests pass" as audit success — the audit's purpose
  is to find what tests don't cover.
- Modifying source files inside the audit agents (they are
  read-only; fixes are a separate phase).

## When NOT to use

If the previous review rounds were Codex-methodology (this
playbook) and produced few findings, the port is genuinely
parity-clean and re-running the same sweep will not change that.
The "switch to this playbook" recommendation is specifically for
codebases that have only had Rust-side reviewer rounds.
