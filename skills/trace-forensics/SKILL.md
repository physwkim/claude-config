---
name: trace-forensics
description: Diagnose from a capture that already exists (perf.data, an Intel PT or ftrace dump, a sampler log, a heap profile, a core dump) by loading it into a queryable form before reading it, then attributing the hot path to source. Use when asked what a trace or profile shows.
---

# Trace forensics

The capture is a fixed dataset: read it, do not re-run it. Instrumenting a live process is a different job.

1. Identify the format and the tool that decodes it: `perf script`, `perf report --itrace=...`, `trace-cmd report`, `gdb` for a core, the heap profiler's own reader.
2. Make it queryable before reading it. Decode to a file, load it into sqlite with one row per sample, frame, event or allocation, and read only query results. Never page a raw dump into context.
3. Narrow to the cause. Query for the frames that hold the most samples and walk the call tree to the hot path. For a leak, follow the allocation site or retainer chain. For a stall, find the thread on-CPU or blocked and its wait reason.
4. Attribute to source. Map the hot frame to file, symbol and line with the artifact's own symbols; the binary must be the one captured (same build id). A frame with no source mapping is not a diagnosis: resolve the symbols, or say the artifact does not carry them.
5. With a paired capture, diff before and after to confirm. Without one, the finding is the strongest hypothesis the artifact supports, not a confirmed cause.
6. Hand back the diagnosis; no fix unless asked.

**Reply:** the artifact and format, the reduced finding, the source location, the paths of the decoded and query files, and whether a paired capture confirmed it.
