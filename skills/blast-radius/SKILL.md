---
name: blast-radius
description: Find what a change could break outside its diff, and prove the one fact it is safe because of by running real code instead of writing it up. Use for "blast radius of X", "what could this break", or a small diff you do not trust yet.
---

# Blast radius

Listing callers is not the job; `rg` does that in a second. The job is the breakage a symbol search does not show. Finding other sites of the same defect is the `rg` audit in CLAUDE.md; this is about what the change breaks elsewhere.

A writeup that sounds right reads the same whether or not it is true. Find the one or two facts the change's safety rests on and prove them by running code.

## Proof ladder

Take each load-bearing fact as far down as is cheap, and say where it stopped:

1. Said so. Worthless alone.
2. Pointed at the line: a real `file:line`, or the dependency's source at its locked version.
3. Walked the failure step by step and showed it does not reach.
4. Ran it: a test or script that calls the real code and fails loudly if the fact is false.
5. Reproduced it in the running system.

Rung 4 is usually one small test that calls the exact function in question.

## Steps

1. Read the change: the diff, every symbol it adds, changes or removes, and what it now does differently that the diff does not spell out.
2. Find the one fact it is safe because of ("this call only drops entries that are already dead"). If it holds, most risks clear at once. Spend the time here, not on a list of maybes.
3. Look where `rg` stops: the dependency's source at the version in `Cargo.lock` and any `[patch]`; when things run (drop order, cancellation at an `.await`, a lock held across one, callback threads, shutdown); what a symbol search misses (bytes on the wire another implementation reads, a db field or env var, a feature flag or `cfg` branch, code three hops downstream).
4. Rate each risk by real likelihood and real cost. Keep the confirmed ones; list the checked-and-cleared ones separately. Cite real `file:line`; a search that finds nothing is an answer; never invent a caller or an API.
5. Prove the one fact: write the test or script, run it, paste the result.

## Hand back

- What it does, including the part that is not obvious.
- The fact it is safe because of: the rung reached and the proof, or "unproven".
- Risks: how each breaks, `file:line`, likelihood and cost, how to check.
- Cleared: what was checked and why it is fine.
- Before merge: the cheapest test or repro that would catch the real bug.

Strip anything private before it goes anywhere public.
