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
   independently green helpers, fixtures, tests, and docs with non-overlapping ownership.
4. **Schema migration** — red; use Postgres/data protections and route implementation
   through Terra plus fresh Sol review.
5. **React URL filter** — green when the owned behavior is local and established; Luna
   is eligible with production-delivery plus React production-delivery.
6. **Mixed React/backend** — decomposed into non-overlapping workstreams, with profiles per workstream
   rather than forcing every stream to carry React requirements.

## Executable routing truth table

This case-scoped table is authoritative for the representative outcomes below. The
acceptance verifier parses it as JSON and mutation-checks contradictory risk, lane,
profile, and fresh-review outcomes; prose elsewhere cannot satisfy a missing field.

```json routing-truth-table
{
  "version": 1,
  "cases": [
    {
      "id": "pure-typescript-mapper",
      "policy": "economy",
      "risk": "green",
      "lane": "luna-app-task",
      "profiles": ["production-delivery", "typescript-backend-delivery"],
      "fresh_sol_review_required": false
    },
    {
      "id": "pg-boss-ownership-reconciliation",
      "policy": "economy",
      "risk": "amber",
      "lane": "decomposed-mixed",
      "profiles": ["production-delivery", "postgres-data-delivery", "worker-integration-delivery"],
      "terra_owns": "consistency core",
      "luna_owns": "independently-green helpers, fixtures, tests, or docs only",
      "fresh_sol_review_required": false
    },
    {
      "id": "fle-1007-like-backend-data-worker",
      "policy": "economy",
      "risk": "amber",
      "lane": "decomposed-mixed",
      "profiles": [
        "production-delivery",
        "typescript-backend-delivery",
        "postgres-data-delivery",
        "worker-integration-delivery"
      ],
      "ownership": "pg-boss admission, database ownership metadata, provider-request state, worker safeguards, and orphan reconciliation",
      "fresh_sol_review_required": false
    },
    {
      "id": "schema-migration",
      "policy": "balanced",
      "risk": "red",
      "lane": "terra-native",
      "profiles": ["production-delivery", "postgres-data-delivery"],
      "fresh_sol_review_required": true
    },
    {
      "id": "legacy-react-url-filter",
      "policy": "economy",
      "risk": "green",
      "lane": "luna-app-task",
      "profiles": ["production-delivery", "react-production-delivery"],
      "invocation": "@react-sol-advisor",
      "fresh_sol_review_required": false
    },
    {
      "id": "critical-mechanical-luna",
      "policy": "critical",
      "risk": "green",
      "lane": "luna-app-task",
      "profiles": ["production-delivery"],
      "fresh_sol_review_required": true
    },
    {
      "id": "bounded-queue-lease-transition",
      "policy": "balanced",
      "risk": "amber",
      "lane": "terra-native",
      "profiles": ["production-delivery", "worker-integration-delivery"],
      "fresh_sol_review_required": false
    },
    {
      "id": "bounded-orphan-reconciliation-state-machine",
      "policy": "balanced",
      "risk": "amber",
      "lane": "terra-native",
      "profiles": ["production-delivery", "worker-integration-delivery"],
      "fresh_sol_review_required": false
    },
    {
      "id": "bounded-unsettled-stale-response-race",
      "policy": "balanced",
      "risk": "amber",
      "lane": "terra-native",
      "profiles": ["production-delivery", "worker-integration-delivery"],
      "fresh_sol_review_required": false
    }
  ]
}
```
