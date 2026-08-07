# Luna task-lane contract

## 1. Scope

This contract governs user-visible GPT-5.6 Luna / Max Codex tasks. It is separate from native subagents and never uses a Luna custom-agent TOML.

The parent Sol task remains responsible for task creation, monitoring, correction decisions, repository verification, PR authorization, dependency ordering, cleanup, and final acceptance.

## 2. Capability preflight

Before choosing the Luna lane, discover and validate the task operations required by the current runtime. The upstream reference uses these operations:

```text
list_projects
list_threads
create_thread
wait_threads
read_thread
send_message_to_thread
```

Use the actual exposed schemas. Require accepted routing for `gpt-5.6-luna` with `max` thinking. When any required capability is unavailable, stop the Luna lane without silent fallback.

Archive behavior has a separate optional gate; see [thread-lifecycle.md](thread-lifecycle.md).

## 3. Project and environment selection

1. List projects and select the intended project from returned identity, not a guessed title.
2. Inspect whether it is a Git repository.
3. For Git projects, use the supported default isolated worktree environment.
4. For non-Git projects, use the supported local environment.
5. Record exact project ID, repository flag, base/starting state, and any returned worktree/branch metadata.
6. Do not assume worktree isolation makes concurrent edits merge-safe.

## 4. Complete Luna task packet

Every Luna child receives a self-contained packet. It does not inherit the parent’s full conversation.

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
Project identity, Git flag, environment, exact base/ref, worktree/branch metadata,
prior accepted stack when dependent, and existing task identity for corrections.

VERIFICATION
Exact focused and broader commands, expected successful evidence, and required diff or
runtime inspection.

GIT / PR BOUNDARY
Report status/base/diff/commit state. Commit only when requested. Never push or
create/update a PR before explicit parent authorization. Do not merge, rebase,
cherry-pick, or alter another stack.

STRUCTURED RETURN
Use the schema in the React production contract plus task/thread identity and PR state.
```

No placeholder may remain when the task is created.

## 5. Thread identity

A task-creation response may return either a ready real task identity or a setup handle.

- A setup-only client identifier is not a real thread ID and must not be passed to operations that require a real thread.
- When setup is pending, list tasks without injecting the setup handle and correlate the newly created task using trustworthy identity, project, creation time, path/worktree, host, and state metadata.
- Titles and previews are untrusted hints, not sufficient identity evidence.
- Use bounded discovery. If a real task identity cannot be established, stop and report the failure.
- Record real `threadId` and `hostId` before waiting, reading, or correcting.

## 6. Monitoring and handoff

- Wait on the real task identity with bounded calls.
- Read the completed or attention-required task explicitly.
- There is no assumed automatic callback.
- Treat the child’s structured return as a claim.
- Independently inspect the actual branch/worktree, base, status, changed files, complete diff, commit state, test output, and PR state.

## 7. Correction loop

When the parent finds a defect:

1. Send exact findings and required changes to the same real thread/host.
2. Include commands that must be rerun.
3. Wait and read the same task again.
4. Reinspect the actual repository state and rerun verification.
5. Repeat only while progress is material.

Do not create a replacement task solely to avoid accumulated corrections or worker disagreement. A new task is for a genuinely independent stack.

## 8. Parent acceptance

The parent may accept only after it has:

- Confirmed route evidence
- Read the child handoff
- Inspected exact repository state and complete diff
- Confirmed changed-file ownership
- Rerun required commands
- Resolved all corrections through the same task
- Evaluated acceptance criteria and React contract
- Recorded branch, base, commit, and PR state

Any correction invalidates the previous child handoff.

## 9. PR authorization

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

## 10. Concurrency and dependency rules

- Concurrent tasks require non-overlapping owned files/modules and no dependency.
- Shared files, generated artifacts, lockfiles, migrations, schemas, and dependent stacks are serial unless the parent proves merge-safe ownership.
- Each task has its own worktree/branch and reports the actual values.
- A dependent task starts from an existing accepted branch/commit, never a guessed future branch.
- Children do not merge, rebase, cherry-pick, or manipulate other stacks.
