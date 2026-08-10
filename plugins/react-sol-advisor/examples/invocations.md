# Sol Development Advisor invocation examples

## 1. Default economy mode from Linear

```text
@react-sol-advisor Implement Linear issue FLE-123 using economy mode.
Use Luna for every bounded task that fits the routing policy. Select mandatory
production-delivery plus only the conditional profiles required by owned paths.
Create a draft PR only after parent acceptance, then archive accepted child tasks when
a supported archive operation is available. Otherwise return the thread IDs that are
safe for me to archive.
```

## 2. Direct request without Linear

```text
@react-sol-advisor In this Next.js repository, add an accessible customer-status filter
that persists in the URL and follows the existing vehicle-filter implementation.
Use economy mode. Do not create a PR; leave an accepted commit and verification report.
```

## 3. Balanced mode

```text
@react-sol-advisor Implement FLE-456 using balanced mode.
Use Terra for any unresolved Next.js caching, race-condition, or cross-package contract
work. Use Luna for bounded UI, tests, and mechanical call-site changes.
Create a draft PR after acceptance.
```

## 4. Critical mode

```text
@react-sol-advisor Implement FLE-789 using critical mode.
This changes tenant authorization and a shared API contract. Keep Sol on architecture,
use Terra for implementation, require a fresh Sol final review, and do not create a PR
until the final verdict is SHIP.
```

## 5. Review an existing branch

```text
@react-sol-advisor Review the current branch against Linear issue FLE-321.
Do not implement initially. Normalize the issue, classify risk, inspect the complete
diff and checks, then return ship/fix-first/rethink. Route confirmed fixes according to
economy policy.
```

## 6. No expensive fallback

```text
@react-sol-advisor Implement this bounded issue in economy mode.
If Luna / Max app-task routing is unavailable, stop and report the missing capability.
Do not fall back to Terra unless I explicitly authorize it.
```

## Expected initial response shape

```text
ISSUE INTAKE
...

ROUTING DECISION
POLICY: economy
RISK: green
LANE: luna-app-task
REASONS:
- existing canonical implementation
- bounded feature ownership
- no public contract or database change
OWNERSHIP:
- apps/portal/src/features/vehicles/...
DELIVERY PROFILES:
- production-delivery
- react-production-delivery for this owned URL/UI slice
ESCALATION TRIGGERS:
- URL-state contract differs from canonical example
- shared API must change
PR POLICY: draft-after-acceptance
```

## 7. Backend/data/worker and mixed work

```text
@react-sol-advisor Add a deterministic TypeScript mapper using economy mode. The owned
path is backend-only: apply production-delivery plus typescript-backend-delivery; do
not require React. Use Luna / Max only if the canonical mapper pattern and tests make
it green.
```

```text
@react-sol-advisor Add pg-boss admission and orphan reconciliation. Select
production-delivery, postgres-data-delivery, and worker-integration-delivery. Classify
schema or consistency impact honestly; keep the Terra irreducible core separate from
bounded Luna fixtures, tests, or documentation.
```

```text
@react-sol-advisor Implement a React URL filter plus its backend query mapping. Decompose
into non-overlapping React/UI and backend workstreams, select profiles per workstream,
and retain Sol as architect and acceptor. Do not make backend work carry React merely
because the request also has a UI stream.
```

## 8. Exact-thread fallback and same-thread correction

```text
@react-sol-advisor Implement this bounded React change in economy mode.
If wait_threads is absent but list_projects, list_threads, create_thread, read_thread,
and send_message_to_thread are exposed, use bounded exact-thread read_thread polling.
Inspect the actual list_projects schema, record projectKind and supportsWorktrees, and
request {type: "worktree"} only when supportsWorktrees is true. The initial child packet
contains only pre-creation project, environment, base, ownership, interface, constraint,
and verification data; keep real thread, host, child-worktree, monitoring, and turn IDs
in a separate parent lifecycle record after creation.
Use list_threads only to resolve a real identity when creation returned a setup handle.
After identity resolution, monitor only the same real threadId and hostId. Accept only a
latest completed turn with a readable final assistant handoff plus independent child
worktree/diff verification. If a correction is needed, make the correction call with the
same real threadId, same hostId, and same child worktree, explicitly pass
model = gpt-5.6-luna and thinking = max, record any returned routing metadata, and
require a new completed turn ID with an updated handoff. Fail closed on timeout,
notLoaded, idle without a new completed turn, unsafe project environment, or missing
exact project registration.
```
