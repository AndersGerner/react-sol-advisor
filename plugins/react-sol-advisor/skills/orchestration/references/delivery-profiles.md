# Delivery profiles

This is the canonical selection matrix for implementation delivery profiles. It
selects engineering requirements from owned path and observable acceptance needs; it
does not select a model lane and is independent of risk classification. Apply
`production-delivery` always. Add specialist profiles conditionally, and combine them
when one workstream genuinely owns more than one concern.

## Selection matrix

| Owned path or acceptance need | Required profiles | Selection note |
| --- | --- | --- |
| Any implementation task | `production-delivery` | Always required. |
| React, Next.js, React Native, Expo, or UI rendering/state | `production-delivery` + `react-production-delivery` | Conditional on an owned React/UI path or acceptance criterion. |
| TypeScript service, API, event, mapper, or backend logic | `production-delivery` + `typescript-backend-delivery` | TypeScript is not auto-React; absence of React is allowed. |
| Postgres schema, query, transaction, persistence, or data invariant | `production-delivery` + `postgres-data-delivery` | Database work can combine with a backend or worker profile. |
| Provider, queue, worker, background work, or external side effect | `production-delivery` + `worker-integration-delivery` | Provider, worker, and database work is not green merely because it is TypeScript. |

Profile selection is independent of risk. Risk determines the delivery route after the
profiles are selected; profiles describe what the implementation must protect. The
matrix is combinable: a React/backend request can use a UI workstream and a backend
workstream, each with the profiles its ownership requires.

## Representative selection examples

1. **Pure deterministic TypeScript mapper** — green; Luna / Max is eligible when the
   change has production-delivery plus TypeScript backend and stays deterministic.
2. **Bounded REST handler following established pattern** — green or amber according
   to contracts and side effect ownership; apply production-delivery plus TypeScript
   backend, adding a data or integration profile only when the owned behavior requires it.
3. **pg-boss admission plus ownership/orphan reconciliation** — amber or red depending
   on schema and consistency impact. Terra owns the irreducible core; Luna may own
   bounded helpers, fixtures, tests, and docs with non-overlapping ownership.
4. **Schema migration** — red; use Postgres/data protections and route implementation
   through Terra plus fresh Sol review.
5. **React URL filter** — green when the owned behavior is local and established; Luna
   is eligible with production-delivery plus React production-delivery.
6. **Mixed React/backend** — decomposed into non-overlapping workstreams, with profiles per workstream
   rather than forcing every stream to carry React requirements.
