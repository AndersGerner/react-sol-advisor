# Example Luna task packet

This is illustrative. The parent must replace every value with repository evidence.

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
- Project ID: <actual returned ID>
- Git repository: true
- Environment: isolated worktree
- Base: <actual branch and commit>
- Existing task identity: none
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
- Do not push or create/update a PR before `PR AUTHORIZED FOR <threadId>`.
- Do not merge, rebase, cherry-pick, or alter another stack.

STRUCTURED RETURN
STATUS: complete | partial | blocked
TASK ID: real threadId and hostId
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
```
