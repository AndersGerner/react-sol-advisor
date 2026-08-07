# Model routing policy

## 1. Purpose

Routing must be predictable, explainable, and cost-aware. The parent does not choose a lane based on file count or intuition alone. It evaluates whether architecture is settled, ownership is bounded, behavior is testable, and failure blast radius is acceptable.

## 2. Required route-decision output

Before delegation, emit:

```text
ROUTING DECISION
POLICY: economy | balanced | critical
RISK: green | amber | red
LANE: luna-app-task | terra-native | sol-parent-only | decomposed-mixed
REASONS:
- concise evidence-based reason
OWNERSHIP:
- exact files/modules or bounded responsibility
QUALITY CONTRACT:
- selected React/platform references
ESCALATION TRIGGERS:
- exact conditions that stop or change the lane
PR POLICY: none | commit-only | draft-after-acceptance
```

## 3. Green classification

Classify green only when **all** of the following are true:

- The requested outcome can be expressed as observable acceptance criteria.
- The repository contains an established architecture or canonical example for the change.
- State and data ownership are clear.
- The worker can own a bounded file/module set without changing shared contracts.
- Relevant tests and verification commands are known.
- No red trigger applies.
- No unresolved product or architecture decision remains.
- Failure would be local and reversible.

Common green examples:

- Component or screen implementation using an existing pattern
- Form and validation changes inside an established feature
- React Query query/mutation following existing conventions
- Loading, empty, error, and accessibility improvements
- Focused hooks with clear ownership
- Unit/integration tests
- Storybook stories
- Local refactors with preserved public behavior
- Straightforward Next.js page or React Native/Expo screen work
- Reproducible bounded bug with a regression test

## 4. Amber triggers

Any of these makes the task amber unless a red trigger also applies:

- React Server Component/client boundary decisions
- Hydration, streaming, Suspense, or partial rendering behavior
- Next.js caching, revalidation, or invalidation semantics
- Race conditions, cancellation, stale responses, or complex optimistic updates
- Shared state crossing feature or package boundaries
- Multi-package monorepo changes with established but non-local contracts
- Performance work requiring measurement and diagnosis
- React Native navigation, linking, app lifecycle, offline, background, or platform-specific behavior
- Complex accessibility focus management or live-region behavior
- Refactor with broad behavioral surface despite a small diff
- Production bug whose cause is not yet localized
- Competing repository patterns without a clearly designated canonical example

## 5. Red triggers

Any of these makes the task red:

- Authentication, authorization, security policy, secrets, or tenant isolation
- Billing, financial calculations, payments, or legally consequential behavior
- Database schema, migration, destructive data operation, or consistency policy
- Public API, shared package contract, generated schema, or externally consumed interface
- Framework-wide upgrade or major dependency migration
- Native module development or native build-system changes
- New cross-application domain model or package boundary
- Incident response with unclear root cause and broad production impact
- Irreversible operation or material data-loss risk
- User request conflicts with repository architecture or safety policy
- Acceptance criteria or ownership cannot be resolved without a senior decision

## 6. Policy mapping

### Economy

| Risk | Default route |
|---|---|
| Green | Luna / Max app task; parent Sol verifies and accepts |
| Amber | Sol decomposes into green Luna units where possible; Terra handles only the irreducible amber core |
| Red | Sol settles architecture; Terra / High implements; fresh Sol reviewer required |

For amber work, `decomposed-mixed` is preferred over sending the entire task to Terra when clean ownership boundaries exist.

### Balanced

| Risk | Default route |
|---|---|
| Green | Luna / Max app task |
| Amber | Terra / High by default, or Luna for explicitly bounded subparts |
| Red | Terra / High plus fresh Sol reviewer |

### Critical

Critical is the explicitly expensive safety policy. Every critical task receives a fresh
Sol review after parent verification, even when the implementation itself is green.

| Risk | Default route |
|---|---|
| Green | Terra / High plus fresh Sol reviewer required unless the parent identifies a purely mechanical Luna subtask |
| Amber | Terra / High plus fresh Sol reviewer required |
| Red | Sol architecture, Terra / High implementation, mandatory fresh Sol reviewer |

## 7. Fresh Sol review

A fresh native Sol reviewer is required after Terra implementation when:

- The risk class is **red**.
- The policy is **critical**.
- An **amber** task touches a consequential commitment boundary, such as a public API,
  authentication/authorization, migrations, database schema, irreversible data operation,
  generated contract, or broad cross-package refactor.

A fresh Sol review is **not** required for routine green Terra work outside critical
policy or for non-consequential amber implementation that the primary Sol session can
accept after inspecting the diff and rerunning verification. Do not invoke a fresh
reviewer merely for reassurance.

## 8. Luna escalation triggers

A Luna worker must stop and return `blocked` or `partial` rather than improvising when:

- Required ownership expands outside the packet.
- Repository evidence contradicts a settled interface or architecture decision.
- A public contract, schema, auth policy, or data model must change.
- A required canonical example does not exist or is internally inconsistent.
- Verification fails for a reason that is not localized after two materially different diagnostic attempts.
- The requested behavior creates an unaddressed race, security, migration, or compatibility risk.
- Required task tools, repository access, model, or reasoning effort cannot be observed.
- Another concurrent change overlaps owned files or invalidates the selected base.

The parent then revises the packet, decomposes further, or routes the unresolved core to Terra. It must not send the unchanged prompt repeatedly.

## 9. Cost controls

- Sol produces concise decision packets rather than implementation essays.
- Do not paste entire issues, logs, or skill manuals when a normalized summary and exact references suffice.
- Load only applicable React/platform references.
- Keep child ownership narrow enough to avoid repeated repository rediscovery.
- Use focused test output; summarize large logs and point to files.
- Reuse the same child for corrections.
- Create a fresh parent per issue or coherent feature stack rather than keeping an immortal orchestrator thread.
- Do not invoke Terra or a fresh Sol reviewer merely for reassurance; require a policy trigger.

## 10. No silent fallback

When a chosen lane is unavailable:

- Report the missing capability.
- Preserve the intended route in the report.
- State the exact alternative and its expected cost/risk implication.
- Require explicit user authorization before switching to a more expensive lane.

Availability is not permission to violate the policy.
