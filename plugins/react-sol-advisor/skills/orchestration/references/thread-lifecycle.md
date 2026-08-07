# Thread lifecycle and capability-gated archiving

This reference is a focused companion to [luna-task-lane.md](luna-task-lane.md).
The canonical Luna task packet, preflight, project selection, thread identity,
monitoring, correction loop, parent acceptance, and PR authorization rules live in
`luna-task-lane.md`. This file covers the end-of-lifecycle concerns: archiving,
parent final return, and the concurrency rules that affect both.

## Concurrency and dependency rules

See [luna-task-lane.md](luna-task-lane.md) for the canonical concurrency and
ownership rules. The only addition for archiving is that archived or
ready-to-archive tasks must also have non-overlapping files and no unresolved
correction with any still-active task.

## Capability-gated archiving

Archiving is optional cleanup, not a correctness prerequisite.

### Supported archive operation exists

- Inspect the real schema before calling it.
- Archive only accepted child tasks with no unresolved correction.
- Require branch/commit/PR evidence to be recorded first.
- Capture returned success evidence.
- Do not delete tasks.
- Do not archive the active parent before its final handoff.

### No supported archive operation exists

Return:

```text
THREADS_READY_TO_ARCHIVE:
- threadId: ...
  hostId: ...
  reason: accepted; branch/commit/PR recorded
```

Do not access undocumented app-server transport, local databases, session files, or task
storage to simulate archive behavior.

## Parent final return

```text
STATUS: complete | partial | blocked
ROUTE: policy, risk, lane, and observed evidence
TASKS: real identities and final states
CHANGES: accepted file-by-file summary
VERIFIED: parent-run commands and results
GIT: base, branch, commit, status, PR
CORRECTIONS: count and decisive fixes
THREAD CLEANUP: archived with evidence | ready-to-archive list | none
RESIDUAL RISK: material remaining risk, or none
```
