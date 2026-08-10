---
name: typescript-backend-delivery
description: >
  Specialist delivery profile for TypeScript services, APIs, event handlers, and
  deterministic backend logic.
---

# TypeScript backend delivery profile

Use [production-delivery](../production-delivery/SKILL.md) for every implementation
task, then add this profile when the owned path includes TypeScript backend behavior.

## Boundaries and contracts

Keep domain, service, and repository responsibilities distinct. Maintain dependency direction
from transport and infrastructure toward the domain; do not let a transport handler become the
owner of business policy. Define input and output contracts at every external boundary and apply
runtime validation before data enters trusted code.

Use exhaustive error types for expected failures and preserve clear compatibility for
both API and event compatibility contracts. Model timeout and cancellation explicitly.
Protect idempotency and duplicate calls, and classify retry classification so callers
can distinguish a retryable condition from a permanent result.

## Errors and observability

Permit no swallowed errors. Map failures to deliberate typed results or propagate them
to the established error boundary with sufficient safe context. Preserve logging,
tracing, metrics, and correlation identifiers across request and event boundaries.

Maintain strict TypeScript and narrowed external data: parse or validate unknown input,
then narrow it before use. Avoid broad casts, untyped map payloads, and assertions that
hide a missing runtime invariant.

## Tests and verification

Design deterministic test seams around input parsing, domain decisions, repository
ports, clocks, and transport adapters. Cover success, exhaustive error behavior,
timeout, cancellation, duplicate calls, retry classification, and API/event
compatibility when the owned behavior has those paths. Report the exact verification
evidence required by production-delivery.
