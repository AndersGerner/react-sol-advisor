---
name: worker-integration-delivery
description: >
  Specialist delivery profile for workers, queues, providers, recovery, and external
  side effects.
---

# Worker and integration delivery profile

Use [production-delivery](../production-delivery/SKILL.md) for every implementation
task, then add this profile when the owned path includes workers, queues, providers, or
an external side-effect boundary.

## Admission and job lifecycle

Define admission and dedup before work enters the system. Document job ownership,
leasing, heartbeat, and expiry so a live owner is distinguishable from abandoned work.
Assume at-least-once delivery: handlers must be idempotent and reentrant.

Specify retry, backoff, and poison behavior. Define timeout, cancel, crash, and restart
handling before implementation. A provider request state machine must identify terminal
states and the safe action for each transition.

## Ordering, recovery, and observability

Handle out-of-order, duplicate, and late events deliberately. Reconcile orphan work
with explicit ownership evidence and use race-safe transitions for competing workers.
Make recovery observable through metrics, alerts, and diagnostics that preserve the
correlation needed to investigate an operation.

Keep the external side-effect boundary narrow and explicit: persist the intent and
result needed to survive a retry, and do not claim completion before the authoritative
outcome is known. Use deterministic fake provider, clock, and queue tests for
admission, leasing, expiry, retry, restart, terminal results, ordering, and
reconciliation.
