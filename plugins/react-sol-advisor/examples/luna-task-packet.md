# Example pre-creation Luna child packet

The first code block is the self-contained prompt sent through `create_thread`. Replace
every pre-creation value with repository and `list_projects` evidence before the call.
Do not add thread, host, child-worktree, monitoring, or completed-turn values. The
parent records thread/host and monitoring mode after creation, then records the child
worktree when the first exact read reveals it.

```text
ROLE
Act as React Sol Advisor's Luna implementation worker. Implement the settled change
inside the owned scope. Use the core React production-delivery contract and the
selected accessibility/testing reference. Do not redesign architecture, modify outside
ownership, push, or create/update a PR without explicit parent authorization. Preserve
concurrent work and report a blocker when repository evidence contradicts this packet.

OBJECTIVE
Add a keyboard-accessible vehicle-status filter to the portal list. The selected value
must be represented in the URL, survive reload, and produce the same server-query input
as the existing leasing-status filter.

ACCEPTANCE CRITERIA
1. The user can select All, Active, or Inactive with keyboard or pointer.
2. Selection updates the `vehicleStatus` search parameter without removing unrelated
   search parameters.
3. Reload restores the selected option.
4. Invalid values fall back to All and are normalized on the next user change.
5. Loading, empty, error, and populated list behavior remain unchanged.
6. The control has an accessible name and visible focus.
7. Focused integration tests cover URL persistence and invalid-value behavior.

REPOSITORY CONTEXT
- Next.js and dependency versions: read from the current package manifest and record.
- Repository instructions: list exact AGENTS.md files read.
- Canonical URL filter: `apps/portal/src/features/vehicles/filters/leasing-status-filter.tsx`
- Canonical query mapping: `apps/portal/src/features/vehicles/queries/vehicle-list-query.ts`
- Canonical test helper: `apps/portal/src/features/vehicles/__tests__/render-vehicle-list.tsx`

FILES AND OWNERSHIP
You own only:
- apps/portal/src/features/vehicles/filters/vehicle-status-filter.tsx
- apps/portal/src/features/vehicles/filters/vehicle-filter-schema.ts
- apps/portal/src/features/vehicles/queries/vehicle-list-query.ts
- apps/portal/src/features/vehicles/__tests__/vehicle-status-filter.test.tsx

You do not own:
- shared API schemas
- database code
- unrelated list components
- lockfiles

INTERFACES
- Preserve the existing vehicle-list query function signature.
- Add only the established optional filter field to the local query input.
- Preserve unrelated URL parameters.
- Use the repository's current router/search-param helper.

REACT QUALITY CONTRACT
- Derive selected state from validated URL state; do not mirror it through an effect.
- Use semantic controls and an accessible group/name.
- Keep interaction logic in event handlers.
- Avoid new global state or abstractions.
- Follow canonical query and test patterns.
- Add behavioral tests before implementation.

CONSTRAINTS
- No shared contract or API changes.
- No unrelated refactor or formatting.
- This task must use GPT-5.6 Luna with Max reasoning.
- Stop if the canonical filter uses a different ownership model than described.

STARTING STATE / BASE
- Project ID: <actual returned ID from the exact intended project>
- projectKind: <verbatim returned value>
- supportsWorktrees: <verbatim returned true or false>
- Requested environment: <exact schema-valid environment; use {type: "worktree"} only when supportsWorktrees is true>
- Independently confirmed repository state: <actual Git or non-Git evidence>
- Base: <actual branch/ref and commit>
- Prior accepted stack: none

VERIFICATION
- Run: pnpm --filter portal test vehicle-status-filter.test.tsx
  Success: targeted tests pass with zero failures.
- Run: pnpm --filter portal typecheck
  Success: exit 0.
- Run: pnpm --filter portal lint
  Success: exit 0 for affected package.
- Inspect: git diff --check and complete owned-file diff
  Success: no whitespace errors or out-of-scope changes.

GIT / PR BOUNDARY
- Report status, base, branch, changed files, diff summary, and commit state.
- Commit only when this packet explicitly requests it.
- Do not push or create/update a PR until a later parent authorization message names the
  accepted task identity.
- Do not merge, rebase, cherry-pick, or alter another stack.

STRUCTURED RETURN
STATUS: complete | partial | blocked
WORKING DIRECTORY: report only when directly observable; the parent verifies it independently
OBJECTIVE: one-line restatement
ACCEPTANCE: each numbered criterion with evidence
CANONICAL EXAMPLES: exact paths used
CHANGES: file-by-file actual diff summary
TESTS: test cases added/changed
VERIFIED: exact commands and concrete results
GIT: branch, base, status, changed files, commit SHA if any
PR: not authorized unless a later parent message explicitly authorizes it
JUDGMENT CALLS: none or exact decisions
GAPS: none or exact blockers
```

No unresolved placeholder may remain in the pre-creation fields when the actual
`create_thread` call is made.

## Parent-owned lifecycle record

This record is created after `create_thread` and is not sent in the initial child prompt.
Populate it from tool results and independent repository inspection, never from guesses
or child claims.

```text
PROJECT ID: exact selected project
PROJECT KIND: verbatim returned projectKind
SUPPORTS WORKTREES: verbatim returned supportsWorktrees
REQUESTED ENVIRONMENT: exact create_thread environment
BASE / STARTING STATE: independently confirmed branch/ref and commit
REAL THREAD ID: actual real threadId returned or uniquely resolved after creation
HOST ID: actual hostId returned or uniquely resolved after creation
CHILD WORKTREE: unresolved until the first exact read returns it; then independently verified path and branch metadata
MONITORING MODE: preferred wait/read | exact-thread read_thread fallback
ROUTING EVIDENCE: accepted creation routing metadata when returned
PREVIOUS COMPLETED TURN ID: none before the initial turn; exact prior ID before correction
LATEST COMPLETED TURN ID: exact newly completed turn accepted by the parent
COMMIT / PR STATE: independently inspected state
```

The real thread and host identities are sufficient to begin monitoring while `CHILD
WORKTREE` remains `unresolved`. The first exact read populates that field; every later
read must remain attributable to the same independently verified worktree.

## Same-thread correction message

Existing identity belongs in this correction call, not in the initial child packet.

```text
TOOL ARGUMENTS
threadId: <same real threadId from the parent lifecycle record>
hostId: <same hostId from the parent lifecycle record>
model: "gpt-5.6-luna"
thinking: "max"

MESSAGE
Correct the following verified defects in the same child worktree:
- <exact finding and evidence>

Previous completed turn ID: <exact prior completed turn ID>
Required worktree: <same independently verified child-worktree path>
Rerun:
- <exact focused verification>
- <exact broader verification>

Return an updated handoff for a new completed turn. Do not push or create/update a PR
unless this correction message separately authorizes it.
```

After every correction call, the parent records any returned routing metadata and stops
if it contradicts Luna / Max. The parent then requires a different newly completed turn
ID, reads the updated handoff, and independently reinspects the same worktree and diff.
