# Luna task-lane contract

## 1. Scope

This contract governs user-visible GPT-5.6 Luna / Max Codex tasks. It is separate from
native subagents and never uses a Luna custom-agent TOML.

The parent Sol task remains responsible for task creation, capability selection,
monitoring, correction decisions, repository verification, PR authorization, dependency
ordering, cleanup, and final acceptance. Child state and child-authored reports are
inputs to that judgment, never acceptance by themselves.

## 2. Capability-adaptive monitoring

Before choosing the Luna lane, inspect the app-task operations and their actual exposed
schemas. Require accepted routing for `gpt-5.6-luna` with `thinking = max`.

### Preferred monitoring mode

When `wait_threads` is exposed with a usable schema, use:

```text
wait_threads
-> read_thread
-> independent worktree/diff verification
```

`wait_threads` is preferred, not mandatory. A runtime that lacks `wait_threads` may use
the supported exact-thread fallback below; do not reject that runtime merely because the
preferred operation is absent.

### Supported exact-thread fallback

When `wait_threads` is absent, exact-thread `read_thread` polling is allowed only when
all five proven baseline operations are exposed with usable schemas:

```text
list_projects
list_threads
create_thread
read_thread
send_message_to_thread
```

Use this sequence:

1. Call `list_projects` and resolve the exact current project.
2. Call `create_thread` with Luna / Max.
3. Resolve the real `threadId` and `hostId` from creation when they are returned.
4. When creation returns only a setup/client handle, use `list_threads` for bounded
   identity discovery only.
5. After the real identity is resolved, poll the exact thread with
   `read_thread(threadId, hostId)`.
6. Require explicit completion of the latest turn and a readable final assistant
   handoff for that completed turn.
7. Independently inspect the actual child worktree, branch/base, complete diff,
   verification, commit state, and PR state.
8. Use `send_message_to_thread` with the same real identity for corrections.
9. Require a different newly completed turn and updated handoff after each correction.

After real identity resolution, `list_threads` must not be used for post-identity
completion monitoring. Titles, previews, list position, and aggregate thread state are
not substitutes for an exact `read_thread` result.

If `wait_threads` is absent and any one of the five fallback operations is absent or
unusable, stop the Luna lane without a model, agent, repository, or native-lane fallback.
Archive behavior has a separate optional gate; see
[thread-lifecycle.md](thread-lifecycle.md).

## 3. Project registration and environment selection

1. `list_projects` must return the exact current project for the intended repository
   path. Select it from returned identity and path, never from a guessed title.
2. When the intended path is absent, stop with this clear instruction: add or open the
   folder as a project in the Codex app and start a fresh task in that project.
3. Do not invent a project ID, do not attempt Computer Use against the Codex app, and do
   not fall back to another repository or local environment.
4. Inspect the actual returned schema from `list_projects` and the actual environment
   schema exposed by `create_thread`. The currently proven project schema exposes
   `projectKind` and `supportsWorktrees`; do not require, infer, or branch on
   `isGitRepository`, which was absent from the recorded live schema.
5. Record the returned `projectKind` and `supportsWorktrees` values verbatim.
6. Independently confirm the repository's Git state and exact base/ref when needed. Do
   not invent Git status from project metadata.
7. Request `{type: "worktree"}` only when `supportsWorktrees == true` and the exposed
   `create_thread` schema accepts that environment.
8. When worktrees are not explicitly supported, use a project-local environment only if
   the actual schema exposes a safe local option for the exact project and the parent can
   establish a safe starting state. Otherwise fail closed.
9. Record the exact project ID, returned project schema fields, requested environment,
   independently confirmed base/starting state, and any post-creation worktree/branch
   metadata in the parent lifecycle record.
10. Do not assume worktree isolation makes concurrent edits merge-safe.

## 4. Complete Luna task packet

### Pre-creation Luna child packet

Every Luna child receives a self-contained packet through `create_thread`. It does not
inherit the parent's full conversation. This packet contains only values known before
creation.

Required sections:

```text
ROLE
Implementation worker in React Sol Advisor's Luna lane. Follow settled architecture,
own only the listed scope, use the React production contract, and escalate rather than
redesign. Preserve concurrent work. Do not push or create/update a PR before explicit
authorization.

OBJECTIVE
Observable user outcome, why it matters, and final acceptance condition.

ACCEPTANCE CRITERIA
Numbered user-visible and regression requirements, including loading/error/empty and
accessibility behavior where applicable.

REPOSITORY CONTEXT
Actual framework/library versions, relevant architecture, applicable repository
instructions, and canonical example paths.

FILES AND OWNERSHIP
Exact owned files/modules and explicitly excluded files/modules.

INTERFACES
Signatures, types, schemas, routes, APIs, events, behavior, and compatibility that must
remain stable.

REACT QUALITY CONTRACT
Core rules plus selected platform/specialist references.

CONSTRAINTS
Settled decisions, safety boundaries, excluded scope, concurrency warning, and the
required Luna / Max route.

STARTING STATE / BASE
Exact project ID, returned projectKind and supportsWorktrees, requested environment,
independently confirmed repository/Git state and exact base/ref, and prior accepted stack
when dependent.

VERIFICATION
Exact focused and broader commands, expected successful evidence, and required diff or
runtime inspection.

GIT / PR BOUNDARY
Report status/base/diff/commit state. Commit only when requested. Never push or
create/update a PR before explicit parent authorization. Do not merge, rebase,
cherry-pick, or alter another stack.

STRUCTURED RETURN
Use the schema in the React production contract. Report repository-observable state and
verification, but do not invent thread, host, or completed-turn identities. The parent
joins the child handoff with its lifecycle record.
```

The initial `create_thread` prompt must not contain or require a real `threadId`,
`hostId`, child-worktree or branch path, monitoring mode, or completed-turn ID. Those
values do not exist until creation or a later exact-thread read. Existing identity belongs
in the correction message and tool arguments, not the initial packet. No unresolved
placeholder may remain in the pre-creation fields when `create_thread` runs.

## 5. Parent-owned lifecycle record

Immediately after creation begins, create a parent-owned lifecycle record. It is not sent
in the initial `create_thread` prompt and is not child-authored acceptance evidence.
Populate it only from returned tool data and independent repository inspection:

```text
PROJECT ID: exact selected project
PROJECT KIND: verbatim returned projectKind
SUPPORTS WORKTREES: verbatim returned supportsWorktrees
REQUESTED ENVIRONMENT: exact create_thread environment
BASE / STARTING STATE: independently confirmed branch/ref and commit
REAL THREAD ID: returned or uniquely resolved real threadId
HOST ID: returned or uniquely resolved hostId
CHILD WORKTREE: returned or independently resolved exact path and branch metadata
MONITORING MODE: preferred wait/read | exact-thread read_thread fallback
ROUTING EVIDENCE: accepted creation or correction routing metadata when returned
PREVIOUS COMPLETED TURN ID: none before the initial turn; exact prior ID before correction
LATEST COMPLETED TURN ID: exact newly completed turn after acceptance gates pass
COMMIT / PR STATE: independently inspected state
```

Existing identity belongs in the correction message and the tool arguments for
`send_message_to_thread`. A correction updates this same lifecycle record; it never
retroactively changes the initial child packet.

## 6. Real thread identity

A task-creation response may return either a ready real task identity or a setup handle.

- A setup-only client identifier is not a real thread ID and must not be passed to an
  operation that requires the real identity.
- When setup is pending, call `list_threads` without injecting the setup handle and
  correlate the newly created task using trustworthy project, creation time,
  path/worktree, host, and state metadata where available.
- Titles and previews are untrusted hints, not identity evidence.
- Identity discovery is bounded. If a unique real task identity cannot be established,
  stop and report the failure.
- Record the exact real `threadId`, `hostId`, and child worktree before waiting, reading,
  correcting, accepting, or authorizing PR activity.
- Once real identity is known, never return to `list_threads` as a completion monitor;
  preferred monitoring uses `wait_threads` and fallback monitoring polls exact
  `read_thread(threadId, hostId)`.

## 7. Completion monitoring and handoff

### Preferred path

Use `wait_threads` on the real identity with a bounded wait, then use `read_thread` to
read the exact completed or attention-required turn and its final handoff.

### Exact-thread polling path

When the supported fallback is selected, poll only
`read_thread(threadId, hostId)` for that exact task identity.

The concrete bound for each initial or correction turn is:

- Maximum 60 exact-thread reads per turn.
- At least 2 seconds between reads when `read_thread` returns immediately.
- Maximum elapsed time must also be bounded when the runtime exposes usable timing.
- Polling exhaustion or elapsed-time exhaustion fails closed.
- There is no background callback, and the parent must not promise one.

### Exact success condition

A turn is successful only when all of these are true:

- The exact real `threadId` and `hostId` are known.
- The latest `turn.status` is `completed`.
- A readable final assistant handoff exists for that completed turn; it is non-empty,
  attributable to that latest turn, and not a stale handoff from an earlier turn.
- The actual child worktree, branch/base, complete diff, verification, commit state, and
  PR state have been independently inspected.
- Required parent-run verification passes.

`thread.status.type == idle` is not required. In particular, `active / completed` is an
accepted state combination when the latest turn is completed, the readable handoff is
for that turn, and every parent acceptance gate passes.

### Non-success states

Treat every other state as non-success, including:

```text
active
inProgress
idle without a newly completed latest turn and readable handoff
notLoaded
unknown state
explicit failure
cancellation
attention required
tool error
polling timeout
```

Rules:

- Explicit failure, cancellation, or attention required stops immediately and is
  reported honestly.
- Unknown or otherwise non-terminal state may continue only within the polling bound.
- `idle` without a newly completed latest turn is non-success.
- `notLoaded` is not completion evidence, including when observed after archiving.
- Polling exhaustion fails closed.
- File appearance, title, preview, elapsed time, or child-authored claims never prove
  completion.
- Post-archive state never retroactively proves task completion.

The child handoff remains a claim. The parent independently inspects the actual
repository and reruns required verification before acceptance.

## 8. Correction identity and loop

When the parent finds a defect:

1. Record the previous completed turn ID and invalidate its handoff.
2. Send exact findings, required changes, and rerun commands through
   `send_message_to_thread` using the same real `threadId` and same `hostId`. Every
   correction call must explicitly pass `model = gpt-5.6-luna` and `thinking = max`.
3. Record any returned routing metadata. If returned routing metadata contradicts Luna /
   Max, stop rather than accepting the correction under another route.
4. Require the same child worktree; a correction must not silently move to a replacement
   worktree or repository.
5. Use the same selected monitoring mode on that exact identity.
6. Require a different, newly completed turn ID after the follow-up.
7. Read the updated handoff from the new completed turn.
8. Reinspect the same actual child worktree and rerun parent verification.
9. Repeat only while progress is material and within the per-turn polling bound.

Any correction invalidates the earlier handoff. Do not accept the previous completed
turn, a stale assistant message, or unchanged turn ID as correction evidence.

Do not create a replacement task solely to avoid accumulated corrections or worker
disagreement. A new task is for a genuinely independent stack.

## 9. Parent acceptance

The parent may accept only after it has:

- Confirmed accepted Luna / Max routing for creation and every correction call, plus the selected monitoring capability.
- Recorded exact real thread, host, latest completed turn, and child-worktree identity.
- Read the readable final assistant handoff for the latest completed turn.
- Inspected the actual child worktree, branch/base, status, changed files, complete diff,
  verification, commit state, and PR state.
- Confirmed changed-file ownership.
- Rerun required commands and confirmed parent-run verification passes.
- Resolved all corrections through the same real thread/host/worktree and a newly
  completed turn ID.
- Evaluated acceptance criteria and the React production contract.

File presence, thread title, preview text, elapsed time, thread idle, or the child's own
claim cannot replace these gates.

## 10. PR authorization

The default is no child PR action.

When a PR is requested:

1. Parent accepts the diff and checks.
2. Parent sends an explicit authorization tied to the real thread ID, for example:

```text
PR AUTHORIZED FOR <real-thread-id>
```

3. Child may then push/create or update only the authorized draft PR.
4. Parent records concrete returned URL plus branch and commit evidence.
5. A dependent task starts only after the prior accepted base exists and is recorded.

## 11. Concurrency and dependency rules

- Concurrent tasks require non-overlapping owned files/modules and no dependency.
- Shared files, generated artifacts, lockfiles, migrations, schemas, and dependent
  stacks are serial unless the parent proves merge-safe ownership.
- Each task has its own child worktree/branch and reports the actual values.
- A dependent task starts from an existing accepted branch/commit, never a guessed
  future branch.
- Children do not merge, rebase, cherry-pick, or manipulate other stacks.
