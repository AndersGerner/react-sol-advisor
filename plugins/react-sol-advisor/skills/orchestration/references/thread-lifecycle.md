# Thread lifecycle and capability-gated archiving

This reference is a focused companion to [luna-task-lane.md](luna-task-lane.md).
The canonical Luna task packet, capability-adaptive monitoring, project selection,
thread identity, exact success condition, correction loop, parent acceptance, and PR
authorization rules live in `luna-task-lane.md`. This file covers end-of-lifecycle
archiving, the parent final return, and concurrency constraints that affect cleanup.

## Concurrency and dependency rules

See [luna-task-lane.md](luna-task-lane.md) for the canonical concurrency and ownership
rules. The only addition for archiving is that archived or ready-to-archive tasks must
have non-overlapping files and no unresolved correction with any still-active task.

## Capability-gated archiving

Archiving is optional for correctness. A task is accepted from exact completed-turn,
readable-handoff, child-worktree/diff, and parent-verification evidence before any
archive operation is attempted.

### `set_thread_archived` is exposed

- Archive only after parent acceptance and after branch, commit, verification, and PR
  evidence have been recorded.
- Inspect the exposed schema before calling the operation.
- Call `set_thread_archived` with the exact real `threadId`, exact `hostId`, and
  `archived = true`.
- Require explicit returned evidence for the same real thread identity with
  `archived = true` and record it.
- Disappearance from listings, `notLoaded`, or any inferred state is not proof of
  archive success.
- Post-archive `notLoaded` or another aggregate state never retroactively proves task
  completion.
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

Do not access undocumented app-server transport, local databases, session files, task
storage, or Computer Use to simulate archive behavior.

## Parent final return

```text
STATUS: complete | partial | blocked
ROUTE: policy, risk, lane, selected monitoring mode, and observed evidence
TASKS: real threadId, hostId, child worktree, latest completed turn ID, and final states
CHANGES: accepted file-by-file summary
VERIFIED: parent-run commands and results
GIT: base, branch, commit, status, PR
CORRECTIONS: count, previous/new completed turn IDs, and decisive fixes
THREAD CLEANUP: archived with explicit returned archived=true evidence | ready-to-archive list | none
RESIDUAL RISK: material remaining risk, or none
```
