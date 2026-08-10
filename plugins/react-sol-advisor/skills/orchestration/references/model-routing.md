# Sol Development Advisor model routing policy

## 1. Purpose and profile selection

Routing is predictable, explainable, and cost-aware. First select mandatory
`production-delivery` and conditional specialist profiles from the canonical
[delivery-profiles.md](delivery-profiles.md) matrix using owned paths and observable
acceptance. That selection is independent of risk: TypeScript is not automatically
React, and absence of React never blocks backend, data, worker, or integration work.

Historical `QUALITY CONTRACT` blocks remain backward-compatible input and records. New
authoritative decisions use `DELIVERY PROFILES`.

## 2. Required route-decision output

Before delegation, emit exactly:

```text
ROUTING DECISION
POLICY: economy | balanced | critical
RISK: green | amber | red
LANE: luna-app-task | terra-native | sol-parent-only | decomposed-mixed
REASONS:
- concise evidence-based reason
OWNERSHIP:
- exact files/modules or bounded responsibility
DELIVERY PROFILES:
- production-delivery plus conditional selected profiles
ESCALATION TRIGGERS:
- exact conditions that stop or change the lane
PR POLICY: none | commit-only | draft-after-acceptance
```

## 3. Green classification

Classify green only when **all** of the following are true:

- The requested outcome can be expressed as observable acceptance criteria.
- The repository contains established architecture or a canonical pattern for the
  change.
- State and data ownership are clear.
- The worker can own a bounded file/module set without shared-contract expansion.
- Relevant tests and verification commands are known.
- Failure blast radius is local and reversible.
- No unresolved product, architecture, data-consistency, or security decision remains.
- No red trigger applies.

Green work can be a deterministic TypeScript mapper, a bounded REST handler following
an established pattern, a React URL filter, focused tests, a local UI behavior, or a
mechanical call site. It is not limited to React.

## 4. Amber triggers

Any of these makes work amber unless a red trigger also applies:

- Non-local concurrency, transaction/locking inside an established design, or
  data-consistency reasoning whose schema is unchanged.
- Async races, cancellation, stale responses, complex optimistic updates, or retry
  classification that changes observable behavior.
- Queues, retries, leases, reconciliation, provider state machines, out-of-order
  delivery, or admission/dedup behavior with established ownership.
- Cross-package behavior with established but non-local contracts, a broad reversible
  refactor, or a production bug whose cause is not localized.
- React Server Component/client boundary decisions.
- Hydration, streaming, Suspense, or partial rendering behavior.
- Next.js caching, revalidation, or invalidation semantics.
- Shared state crossing feature or package boundaries.
- Multi-package monorepo changes with established but non-local contracts.
- Performance work requiring measurement and diagnosis.
- React Native navigation, linking, app lifecycle, offline, background, or
  platform-specific behavior.
- Complex accessibility focus management or live-region behavior.
- Competing repository patterns without a clearly designated canonical example.

## 5. Red triggers

Any of these makes work red:

- Authentication, authorization, security policy, secrets, or tenant isolation.
- Database schema, migration, destructive data operation, RLS, or consistency policy.
- Public API, shared package contract, generated schema, or externally consumed
  interface.
- Billing, financial calculations, payments, or legally consequential behavior.
- Irreversible operation or material data-loss risk.
- Framework-wide upgrade or major dependency migration.
- Incident response with unclear root cause and broad production impact.
- Unresolved consistency or ownership policy, or acceptance criteria that cannot be
  resolved without a senior decision.
- Native module development or native build-system changes.
- New cross-application domain model or package boundary.
- User request conflicts with repository architecture or safety policy.

## 6. Policy mapping

### Economy

| Risk | Default route |
| --- | --- |
| Green | Luna / Max / Fast app task; parent Sol verifies and accepts |
| Amber | Sol decomposes into green Luna units where possible; Terra handles only the irreducible amber core |
| Red | Sol settles architecture; Terra / High implements; fresh Sol reviewer required |

For amber work, `decomposed-mixed` is preferred over sending the entire task to Terra
when clean non-overlapping ownership exists.

### Balanced

| Risk | Default route |
| --- | --- |
| Green | Luna / Max / Fast app task |
| Amber | Terra / High by default, or `decomposed-mixed` when extracted subparts independently satisfy every green criterion |
| Red | Terra / High plus fresh Sol reviewer |

For balanced amber work, boundedness alone is not enough for Luna. Classify every
extracted workstream separately. A queue transition, reconciliation state machine,
cancellation race, or unsettled stale-response behavior remains amber and Terra-owned
even when it fits in one file. Only an independently green helper, fixture, test, doc,
or mechanical call site may use Luna; the aggregate amber task remains
`decomposed-mixed`.

### Critical

Critical is the explicitly expensive safety policy. Every critical task receives a
fresh Sol review after parent verification, even when the implementation itself is green.

| Risk | Default route |
| --- | --- |
| Green | Terra / High plus fresh Sol reviewer required unless the parent identifies an independently green, purely mechanical Luna subtask; fresh Sol review still required |
| Amber | Terra / High plus fresh Sol reviewer required |
| Red | Sol architecture, Terra / High implementation, mandatory fresh Sol reviewer |

Critical Luna contributions do not waive review. After parent verification, the fresh
native Sol reviewer inspects the accumulated task diff, including every Luna-owned
mechanical contribution.

## 7. Fresh Sol review

A fresh native Sol reviewer is required after parent verification when the work crosses
a commitment boundary or the risk class demands it:

- **Red** work in any policy.
- **Critical** work by definition.
- **Amber** work in `balanced` or irreducible `economy` core when it touches
  consequential existing boundaries: public API, authentication/authorization,
  migrations, database schema, irreversible data operations, generated contract, or
  broad cross-package refactor.

Routine green or non-consequential amber Terra work is accepted by the primary Sol
session after diff inspection and verification. Do not spawn a fresh Sol reviewer merely
for reassurance. This economy/balanced cost control does not override the mandatory
critical-policy review, including a critical task implemented wholly or partly through
an independently green Luna contribution.

## 8. Luna escalation triggers

A Luna worker must stop and return `blocked` or `partial` rather than improvising when:

- Required ownership expands outside the packet.
- Repository evidence contradicts a settled interface or architecture decision.
- A public contract, schema, auth policy, or data model must change.
- A required canonical example is missing or internally inconsistent.
- Verification fails for a reason that is not localized after two materially different
  diagnostic attempts.
- The requested behavior creates an unaddressed race, security, migration, or
  compatibility risk.
- Required task tools, repository access, model, reasoning effort, or Fast service tier
  cannot be set and observed.
- Another concurrent change overlaps owned files or invalidates the selected base.

The parent then revises the packet, decomposes further, or routes the unresolved core to
Terra. It must not send the unchanged prompt repeatedly.

## 9. Cost controls

- Sol produces concise decision packets rather than implementation essays.
- Do not paste whole issues, logs, or skill manuals when normalized summaries and exact
  paths/excerpts suffice.
- Load only applicable delivery profiles and references.
- Keep child ownership narrow enough to avoid repeated repository rediscovery.
- Use focused test output; summarize large logs and point to files.
- Reuse the same child for corrections.
- Create a fresh parent per issue or coherent feature stack rather than keeping an
  immortal orchestrator thread.
- Do not invoke Terra or a fresh Sol reviewer merely for reassurance; require a policy
  trigger.

## 10. No silent fallback

When a chosen lane is unavailable, report the missing capability, preserve the intended
route, state the exact alternative and cost/risk implication, and require explicit user authorization before switching to a more expensive lane. Availability is not permission to violate the policy.
