# Native Codex role contracts

Use these contracts with React Sol Advisor's namespaced, role-pinned native custom agents.
They do not launch a nested Codex CLI or change global default-subagent routing. The
separate [Luna task-lane contract](luna-task-lane.md) covers user-visible app tasks;
it is not a native custom-agent role and must not be represented by a companion TOML.
Adapt every placeholder without removing a required field.

## Required preflight

Before every native spawn, complete steps 1-2 of SKILL.md's preflight. After spawning,
complete steps 3-4 before accepting the result:

1. Require the non-mutating companion check to prove both installed files exactly
   match current templates and the retired companion file is absent.
2. Require native exposure of exactly `react_sol_advisor_terra_implementer` and
   `react_sol_advisor_sol_reviewer`.
3. Observe the selected role, model, and effort through public spawn/details metadata
   first, using the local runtime inspector only for omitted fields. Accept only
   Terra / High for implementation and Sol / High for review.
4. For the reviewer, capture actual sandbox policy and permission profile types.

A missing, stale, unsafe, conflicting, unavailable, inconsistent, or unobservable
role/model/effort stops the native lane. Never silently fall back. Model and effort are
pinned by custom-agent TOML, so omit native per-spawn overrides.

## Shared implementation contract

Every Terra prompt must contain all required sections. The React production-delivery
contract is non-negotiable for React, Next.js, React Native, Expo, and TypeScript work.

~~~text
OBJECTIVE
Observable user outcome, why it matters, and the final acceptance condition.

ACCEPTANCE CRITERIA
Numbered user-visible and regression requirements, including loading/error/empty and
accessibility behavior where applicable.

REPOSITORY CONTEXT
Actual framework/library versions, applicable repository instructions/AGENTS.md, canonical
example paths, and any relevant architecture or state conventions.

FILES AND OWNERSHIP
You own only:
- <exact file or module>

You are not alone in the codebase. Other agents or the user may be editing concurrently.
Preserve their edits, do not revert unrelated work, and adapt to changes already present.
Do not modify files outside your ownership.

INTERFACES
- <Signatures, types, schemas, commands, or behavior that must remain compatible.>

REACT QUALITY CONTRACT
Follow the contract in
[react-production-delivery](../../react-production-delivery/SKILL.md)
and load the Next.js, React Native/Expo, and testing/accessibility references when the
task involves those areas. Apply the pre-edit requirements, core implementation rules,
verification order, and structured return. Do not apply generic framework advice without
checking installed versions.

CONSTRAINTS
- <Repository conventions, safety boundaries, excluded scope, and settled decisions.>
- Do not redesign architecture, modify outside ownership, push, or create/update a PR
  without explicit parent authorization.

VERIFICATION
- Run: <exact command>
  Success: <concrete expected result>
- Inspect: <exact file, diff, or generated artifact>
  Success: <concrete expected evidence>

STRUCTURED RETURN
Use the React production-delivery structured return and include:

STATUS: complete | partial | blocked
OBJECTIVE: one-line restatement
ACCEPTANCE: each numbered criterion with evidence
CANONICAL EXAMPLES: exact paths used
CHANGES: file-by-file actual diff summary
TESTS: test cases added/changed
VERIFIED: exact commands and concrete results
GIT: branch, base, status, changed files, commit SHA if any
PR: not authorized | authorized | URL with evidence
JUDGMENT CALLS: none or exact decisions
GAPS: none or exact blockers
~~~

The primary session must inspect the diff and rerun verification itself.

## Luna task lane - separate user-visible app tasks

Green economy work uses the Luna task lane by default. It is outside native subagent V2
and never uses `spawn_agent` or a Luna companion TOML. The child route requires
`gpt-5.6-luna` with `thinking = max` and a complete packet from
[luna-task-lane.md](luna-task-lane.md).

Call `list_projects` first. The exact current project for the intended path must be
returned. If it is absent, stop and instruct the user to add or open the folder as a
project in the Codex app and start a fresh task in that project. Never invent a project
ID, attempt Computer Use against the app, or substitute another repository or local
environment.

Inspect the actual returned schema. The proven project fields are `projectKind` and
`supportsWorktrees`; `isGitRepository` was not exposed and must not be treated as a
required field. Record the returned values verbatim, independently confirm Git state and
the exact base/ref when needed, and request `{type: "worktree"}` only when
`supportsWorktrees == true` and the operation schema accepts it. Use a project-local
environment only when the schema exposes a safe option for the exact project; otherwise
fail closed.

The initial child packet is pre-creation data only: project identity, returned schema
fields, requested environment, exact base/ref, ownership, interfaces, constraints, and
verification. Real thread/host identity, child-worktree metadata, monitoring mode, and
completed-turn IDs belong in a separate parent-owned lifecycle record populated after
creation. Existing identity belongs in the correction message, not the initial packet.

Monitoring is capability-adaptive. `wait_threads` is preferred, not mandatory. With a
usable `wait_threads` schema, wait on the exact real identity and then call
`read_thread`. When `wait_threads` is absent, exact-thread `read_thread` polling is a
supported fallback only if `list_projects`, `list_threads`, `create_thread`,
`read_thread`, and `send_message_to_thread` are all exposed with usable schemas. Missing
Luna, Max, or a capability required by the selected mode stops the lane without silent
fallback.

A ready creation may return the exact real `threadId` and `hostId` immediately. A
setup/client handle is not a real identity. Use `list_threads` only for bounded real
identity discovery when creation did not return the real identity; after resolution it
must not be used for completion monitoring. Titles and previews remain untrusted hints.
The fallback polls only `read_thread(threadId, hostId)` within the documented count,
cadence, and elapsed-time bounds. There is no background callback.

Success requires the latest `turn.status` to be `completed`, a readable final assistant
handoff attributable to that completed turn, independent inspection of the actual child
worktree and complete diff, and passing parent-run verification. `thread.status.type ==
idle` is not required; `active / completed` is accepted when all turn, handoff, and parent
acceptance gates pass. Idle without a newly completed latest turn, `notLoaded`, active or
in-progress work, attention required, explicit failure, cancellation, unknown state,
tool error, or polling timeout is non-success.

Corrections use `send_message_to_thread` with the same real `threadId`, same `hostId`,
and same child worktree. Every correction call explicitly passes
`model = gpt-5.6-luna` and `thinking = max`; record any returned routing metadata and
stop if it contradicts Luna / Max. Record the previous completed turn ID, require a
different newly completed turn ID, read the updated handoff, and repeat parent inspection
and verification. The correction invalidates the earlier handoff.

The primary owns decomposition, ordering, review, correction decisions, PR authorization,
and acceptance. A child may create or push a PR only after explicit primary
authorization; a dependent task starts only after the prior stack is accepted.
Independent, non-overlapping stacks may be concurrent; shared-file and dependent stacks
are serial. Worktree isolation alone is not merge safety.

## Terra / High - sole native implementation lane

Use this lane for every delegated native implementation, from routine edits through
complex, security-sensitive, context-heavy, and broad work. It is not the Luna
task-lane implementation path.

Spawn exactly:

~~~text
agent_type: react_sol_advisor_terra_implementer
fork_turns: none
~~~

The installed role pins GPT-5.6 Terra at high reasoning. Do not attach per-spawn model
or reasoning fields. Require public-details-first runtime observation of the exact
role and pin before accepting its report.

Prompt:

~~~text
ROLE
Act as React Sol Advisor's sole implementation worker. Resolve the supplied specification
within the settled architecture, preserve every stated interface and constraint, and
surface ambiguity instead of redesigning the architecture.

For React, Next.js, React Native, Expo, or TypeScript work, the React production-delivery
contract is mandatory. Load it from
[react-production-delivery](../../react-production-delivery/SKILL.md)
and apply the selected platform/testing references conditionally.

<paste and complete the Shared implementation contract>
~~~

## Fresh Sol - requested-read-only final reviewer

After parent verification, spawn a new native thread exactly:

~~~text
agent_type: react_sol_advisor_sol_reviewer
fork_turns: none
~~~

The installed role pins GPT-5.6 Sol at high reasoning and requests a read-only sandbox.
Do not attach per-spawn model or reasoning fields. Observe the actual role, pin,
sandbox policy, and permission profile before accepting its verdict.

Prompt:

~~~text
ROLE
Act as the fresh final reviewer. Remain strictly read-only: do not edit files, implement
fixes, or broaden scope.

STATED GOAL
<The user's requested outcome.>

ACCUMULATED CHANGE SET
<Exact allowed files plus complete working-tree diff, or explicit base/head revisions.>

INTERFACES AND CONSTRAINTS
- <Compatibility, repository rules, safety boundaries, and excluded scope.>

VERIFICATION EVIDENCE
- <command> -> <actual primary-session output evidence>
- <artifact or diff inspection> -> <actual evidence>

REVIEW
Inspect the actual files and accumulated change set. Judge correctness, completeness,
regressions, scope discipline, interface preservation, test adequacy, and material risk.

SOL REVIEW
VERDICT: ship | fix-first | rethink
REASON: <decisive evidence-based reason>
FINDINGS: <precise file references and required fixes, or none>
RESIDUAL RISK: <most important remaining risk, or none>
~~~

If any fix is made after review, discard the verdict and run a new fresh review.
Sol reviewing Sol is context-clean, not cross-model-family independence.

Use observed isolation, not requested isolation:

- With observed `read-only`, proceed with enforced isolation.
- If the host broadens it, proceed only when hard isolation is not required, the
  prompt forbids edits, and the parent captures and verifies exact before-and-after
  repository and artifact state. Report the broader policy and profile.
- If isolation is unobservable, hard isolation is required, or any mutation occurs,
  stop the lane and do not hide or repair the mutation under that verdict.

## Commitment-boundary Sol consult

For pre-implementation review, spawn the same fresh Sol role with `fork_turns: none`.
Give it the proposed decision, goal, constraints, relevant paths, alternatives, and the
one question that changes the plan. Require `proceed`, `change`, or `stop`, plus the
decisive reason and largest risk. Apply the same preflight, runtime-observation,
sandbox-reporting, and no-fallback rules.
