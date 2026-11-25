---
name: benchmark-checklist
description: Vet a performance number before reporting or acting on it — limiter, tuning, arithmetic limits, errors, repeatability, end-to-end share, and whether the work happened. Use when you run a benchmark or an A/B, or report a speedup or regression you measured.
---

# Benchmark checklist

Answer each question with evidence from a run, not a guess from the code. Machine-specific rigs and protocols in auto-memory (bench box, pinned cores, lock scripts, acceptance round counts) override the defaults here.

## Before the run

- Write the claim you expect to ship, in its final words ("process 0.96 → 0.88 µs at 2,000 records"). Name the result that would change the decision and the noise floor. Stop when the run-to-run spread is larger than the effect.
- Read the harness: what it times, what it counts, what it ignores.
- Binary identity. Build each arm from the tree under test with the build output visible, then `md5sum` both binaries: identical means a build failed and B is A. A clean tree and a fresh mtime do not rule out a leftover profiling build; check its symbols (`nm -C <bin> | rg <probe>`) or rebuild.
- Idle is checked, not assumed: `uptime`, and the processes using CPU. No cargo build or test, profiler, or second bench during the run. A squatter on the same cores hits both arms of an interleaved run, so it never shows as an outlier.

## The questions

1. **Why not double?** Name the limiter from a profile or counters taken in a run you do not report. Watch the load generator: if it saturates first, you measured it. If a change did not move the number, the limiter says why; find it before calling the change useless.
2. **Was it tuned?** Run both arms the way production runs: release profile, same features, flags, env and data, caches as warm as production. A limiter that is a setting (debug build, a commit per row) means that arm is untuned; pick no winner from that run.
3. **Did it break limits?** Do the arithmetic: bandwidth, ops/s × cost per op against the cores, time saved against the share of the changed piece. Removing 10% of the run gains at most about 11%. A result past a limit measured a cache, a no-op or a bug.
4. **Did it error?** Count failures and check that outputs are correct, not only present. Rejections are fast; timeouts and retries are slow. If the harness does not count errors, add the count.
5. **Does it reproduce?** Interleave the arms (A B A B) so warmup and drift favor neither, and report median and range. The run count follows the instrument's noise: instruction counts (`perf stat -e instructions:u`) repeat to the unit, so two interleaved rounds suffice; wall or CPU time and cycles need at least 5 per arm, or a pinned core with its SMT sibling held busy; tail percentiles need many paired rounds and a paired test, and compare only within one run. A gap inside the run-to-run spread is no measurable difference.
6. **Does it matter?** Next to a micro result, measure the end-to-end path and give the micro result as its share. A helper at 1% of a request can make the request at most 1% faster.
7. **Did it happen?** Confirm the work ran inside the window. Count completed work from the system itself (a counter the workload increments), not nominal rate × time: under saturation the nominal denominator makes a slower build read faster. Print achieved/nominal. Lazy code, discarded results and timeouts produce numbers for work that never ran.

## Instrument limits

- A null result is a limit of the instrument, not evidence of no effect. Measure the phase where the change is visible: a round trip dominated by park/unpark hides a queue change.
- Sampled profile shares of small items are upper bounds. A delta under about 100 instructions per operation needs exact counts (Intel PT), not sampling.
- An attached profiler perturbs what it watches (in a VM, vPMU sched-in adds millisecond late wakes). Count tails from profiler-free runs.
- Tick-resolution CPU time (10 ms) cannot resolve small per-operation deltas.

## Report

- Lead with the verdict: faster, slower, no measurable difference, or inconclusive.
- Number with unit, run count, range and limiter: "p50 41 → 33 ms, median of 7 interleaved runs per arm, range 32–35 ms, bound by JSON parsing on one core."
- Inconclusive when you claim a difference but cannot name the limiter, an arm ran untuned, or questions 4 and 7 went unchecked. Name the gap.
- A PR body carries one primary number.

For a ballpark the user asked for, one run is enough; still check 4 and 7, and say it is one run. A choice between options is never a ballpark.
