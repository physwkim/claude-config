# Port translation lessons

Complements `c-parity-audit.md`. That doc tells you how to *run* a
parity audit; this one captures what the audit cannot do, how to
classify what it finds, and what would prevent the next cycle of
findings. Distilled from the 2026-05-18 `epics-pva-rs` ↔ `pvxs`
audit (28 findings, mix of High/Medium).

## Scope

These lessons apply to **wire-faithful Rust ports of long-lived
C/C++ codebases**: the port must interoperate with peers built
against the reference, so the reference's wire behaviour is the
de facto contract regardless of any written spec.

Not in scope: intentional redesign ports (gRPC reimplementation,
new transport, new API surface).

## Lesson 1 — Parity audit is asymmetric

A parity audit finds *divergences* from the reference. By
construction it cannot find:

- Reference-side bugs (the reference itself misreads the spec,
  has races, has CVEs).
- Cases where both port and reference are wrong in the same
  direction.
- Cases where the reference's choice is a historical compat
  quirk that the port would be better off without.

**Implication for triage:** when reporting findings, classify
each one by *independence from the reference*:

1. **Reference-independent defects** — silent data corruption,
   broken public APIs, leaks, panics on internal inputs. These
   are real bugs regardless of what the reference does. Fixing
   them does not depend on the reference being correct.

2. **Reference-faithful gaps** — port is lenient where reference
   closes the connection; port coerces where reference throws.
   Fix = adopt reference's stricter posture. Risk: if the
   reference's choice is itself wrong somewhere, the fix imports
   that bug. Audit one level deeper before mass-applying.

3. **Interop-contract gaps** — wire format mismatch, env-var
   precedence, discovery protocol field. Reference is the de
   facto standard, so matching it is correct by definition even
   if the spec disagrees.

4. **Pure unimplemented features** — handler arm missing,
   architectural decoupling skipped. Audit-orthogonal; these
   are scope decisions, not parity defects.

A finding count without this classification is misleading. The
2026-05-18 audit's 28 findings split roughly: 10
reference-independent, 10 reference-faithful, 5 interop-contract,
3 unimplemented.

## Lesson 2 — "Incomplete feature" is the wrong frame

Most parity-audit findings are not "feature not yet implemented";
they are "feature is wired up and silently does the wrong thing".
Distinguish:

- **Public API silently broken** — builder accepts value, value
  never reaches the runtime. Worse than unimplemented because
  the user has no signal.
- **Silent data corruption** — descriptor and value disagree, wire
  encoder coerces to well-formed wrong data instead of failing.
  Worst class: user receives a valid-looking response that is not
  the data they asked for.
- **Silent resource leak** — operation timeout or error leaves
  server-side state unreaped. Symptom appears later as
  per-channel cap rejection.
- **Silent peer-bug acceptance** — port accepts wire shapes that
  the reference treats as connection-fatal. The port stays up,
  but a buggy or malicious peer can drive state-machine
  confusion that the reference would have prevented.

None of these read as "feature incomplete." All present as
"works in happy-path tests." Treat the framing carefully when
reporting status — "all tests pass" and "port is correct" are
not the same statement.

## Lesson 3 — Inevitability is bimodal

In a faithful port, roughly half the audit findings are
structurally irreducible and half are methodology choices.

### Irreducible (language/paradigm gap)

These appear in every faithful C++ → Rust port. Audit cycles
are the standard way to find them.

- **Exception → Result translation loses connection scope.**
  C++ `throw` in a wire decoder unwinds to a per-connection
  `catch` that closes the socket. Rust translation usually goes
  function-by-function, and each `if let Ok(v) = decode(...)`
  site has to re-decide whether this error is locally recoverable
  or connection-fatal. Local visibility is the wrong scope for
  that decision, so the default becomes "swallow."

  *2026-05-18 examples:* R7, R16, R19, R21, R23, R24, R28.

- **Ownership model mismatch.** `shared_ptr` + a single explicit
  `erase` site that drops both connection-level and channel-level
  maps cleanly translates to `Arc` but the cleanup pattern often
  fragments across `Drop`, scope guards, and per-branch fallback
  paths. A finalizer that the C++ side has as one function
  becomes three Rust paths, only two of which actually run on
  failure.

  *2026-05-18 examples:* R12, R17, R26.

- **Async model differences.** C++ event-loop reactors keep socket
  parsing strictly separate from user-code callbacks, dispatching
  work via control messages. Tokio's `async fn` makes it natural
  to `.await` the user code inline. Both work, but inline `.await`
  loses the head-of-line-blocking immunity the reactor pattern
  provides.

  *2026-05-18 examples:* R14.

- **Trait can't express co-invariants that virtual functions can.**
  C++ `SharedPV::post(value)` validates against the opened
  descriptor in one place — the same class owns both. Rust
  trait `ChannelSource` separates `get_introspection()` and
  `get_value()`; the trait signature has no way to express
  "value must match descriptor." Validation slips out of the
  type and into runtime checks that the port often forgets.

  *2026-05-18 examples:* R5, R9.

### Methodology choice (front-load vs back-load)

These are avoidable with discipline, but discipline costs.

- **API stub left half-implemented.** Builder exposes a public
  setting, value gets stored, plumbing never wired through.
  Detectable with `rg <field>` workspace-wide — if it only
  appears in the builder and the struct that stores it, plumbing
  is missing.

  *2026-05-18 examples:* R1 (`pipeline_size()`), R2 (`tcp_timeout()`).

- **Wire format misread.** Compound array presence byte, header
  field semantics per opcode, extended-form trigger. Detectable
  with byte-exact golden tests captured from the reference; the
  audit cycle is the slow way to find these.

  *2026-05-18 examples:* R13.

- **Field decoded but never read.** Parser pulls a field off the
  wire (proving the implementer saw it) and then nothing
  downstream uses it. Detectable with `rg` for the field name
  beyond the decoder.

  *2026-05-18 examples:* R10 (discovery protocol), R20 (typed
  pvData pipeline option).

- **Env-var alias table not finished.** Reference accepts pairs
  with documented precedence; port reads only one of each pair.

  *2026-05-18 examples:* R15.

## Anti-patterns to flag during port reviews

Independent of running a full audit, watch for these patterns
in any single-file review of a port:

### "C++ throws, Rust swallows"

The reference function has a `throw` or `bad_alloc` or
`reset_connection()` path. The Rust translation has
`if let Ok(...) = decode(...)` or `.ok()` or `let _ =`.

**Triage question:** is the error locally recoverable, or does
it indicate a malformed peer? If the latter, propagate as
connection-fatal, not as a `None` branch.

### Producer/wire boundary collapse

The reference validates at *both* the producer entry point
(e.g. `SharedPV::post()`, `connect(value)`) *and* the wire
encoder. The Rust port validates only at the wire encoder, and
the wire encoder coerces mismatches to well-formed defaults to
stay encodable.

**Triage question:** is there a producer-side gate that rejects
shape mismatch before storing? If not, wire-side coercion will
silently emit wrong data.

### Owner dissolution

The reference has one function that does the cleanup
(`erase(conn_map[ioid])` + `erase(chan_map[ioid])` + sends
`DestroyRequest`). The Rust port spreads cleanup across `Drop`,
a guard struct, a fallback in the error branch, and a
"defused" path on success.

**Triage question:** for every state transition that needs
cleanup, name the *single* owner. If you can't, the cleanup is
unreliable.

### Field decoded into limbo

A struct field is parsed off the wire but no downstream code
reads it. Either the wire side over-decoded (then drop the
field) or the read side missed (then the bug is elsewhere).

**Triage question:** what is the field used for? If "for
future use," delete it until it has a consumer.

## Front-load methodologies that reduce audit cycle count

If a project will need three or more audit cycles, these
investments pay back. Estimated coverage based on the
2026-05-18 finding distribution:

- **Wire golden tests** — capture hex from the reference's
  encoder on a known input; assert the port produces and parses
  the same bytes. Catches the wire-misread class.
  *Would have caught:* R13, R18.

- **Interop CI** — Rust port as client against reference server,
  and reference client against Rust server. Run a fixed scenario
  matrix on every PR.
  *Would have caught:* R1, R10, R11, R20.

- **Malformed-peer fuzzer** — randomised truncation, IOID reuse,
  wrong-command frames, oversized payloads.
  *Would have caught:* R7, R19, R21, R22, R23, R24, R28.

- **Throw-site enumeration pre-port pass** — `rg 'throw|reset|
  disconnect|bad_'` in the reference, produce a table of every
  fatal-error site. Each entry becomes a checklist that the
  Rust translation must explicitly handle.
  *Would have caught:* the "C++ throws, Rust swallows" cluster
  before code review.

These overlap. A project with all four would have caught
roughly 15 of the 28 findings before any review round. The
remaining ~13 are the irreducible language-gap findings that
parity audit cycles are the standard mechanism for.

## What this means for "is the port done"

A port that has had only Rust-side review rounds (no parity
audit) is almost certainly not done, even if all its tests pass.
Rust-side reviewers cannot see what the reference does that the
port doesn't.

A port that has had one parity audit round is partially audited.
Each round finds ~25–30 findings; the next round finds another
batch, not zero, until the language-gap categories are
structurally closed (typically through invariant-enforcing
helpers and golden tests, not through repeated point fixes).

The honest status report is:

- "N findings closed, M open, audit cycle K of expected K+1 or
  K+2 before language-gap categories are structurally closed."

Not:

- "All tests pass, port is parity-clean."
