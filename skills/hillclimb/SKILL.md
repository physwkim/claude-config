---
name: hillclimb
description: Improve one measurable thing (latency, throughput, instructions or allocations per operation) by a loop of one change, one measurement, keep or revert, against a frozen harness, with hypotheses ordered by the performance mantras. Use for a perf issue or a sustained optimization toward a target.
---

# Hillclimb

One change, one measurement, keep or revert. Never stack untested changes; never claim a win from reading code.

1. **Reproduce first.** Trace the target and name the workload dimensions that move the result (size, state, concurrency). Pick a case that reproduces the complaint; if none does, fix the repro instead of climbing. Fix one metric, the better direction, and a stop predicate that pairs a target with a minimum number of attempts, so a lucky early win cannot end the run.
2. **Freeze the harness.** Show it separates a hard case from an easy one; if it cannot, change the workload or the metric. Vet it with `benchmark-checklist`, and make it print its error count and a count of the work done. One command emits the metric, sampled enough to clear the noise. Record the baseline and a passing regression gate (the tests that must stay green) before any change.
3. **Ground each hypothesis** in a mechanism from step 1 ("move X off the cycle path because it allocates per update"), not "try caching something". Order them by the mantras, cheapest first:
   1. Don't do it: stop work whose result nothing uses.
   2. Do it, but not again.
   3. Do less of it.
   4. Do it later.
   5. Do it when nobody is waiting.
   6. Do it concurrently.
   7. Do it cheaper.

   For a one-off fix, stop at the first mantra that meets the target.
4. **Loop**, one hypothesis per iteration: change, measure before and after with the frozen harness, run the gate, and compare the artifacts rather than impressions. Keep only when the metric moves past noise and the gate stays green; otherwise revert in full. An inconclusive or wrong-surface measurement is not a keep. A kept change is one commit (`git add <files>`, never `-A`) whose body carries the measured delta; a reverted one is a line in the reply. No decision-log file.
5. **Past the first plateau.** After several rejects in a row, change category, combine near-misses, re-read the source, or try something more radical. Correctness and simplicity outrank the number: revert a win that breaks behavior, keep a simplification that holds the number.
6. **Stop** when the predicate is met, or when the remaining ideas cost more than they can gain. Do not relax the predicate. If stuck, name the blocker.

**Reply:** metric and target; baseline → final with the delta; iterations kept and reverted; each kept commit and each reverted hypothesis on one line with its measured result; the next idea worth trying.
