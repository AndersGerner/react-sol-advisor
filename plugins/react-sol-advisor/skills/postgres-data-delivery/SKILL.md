---
name: postgres-data-delivery
description: >
  Specialist delivery profile for Postgres data ownership, migrations, concurrency,
  and durable integrity boundaries.
---

# Postgres data delivery profile

Use [production-delivery](../production-delivery/SKILL.md) for every implementation
task, then add this profile when the owned path includes Postgres-backed data behavior.

## Ownership and transaction boundaries

Document authoritative ownership for each record and transition. Put transaction boundaries
around the invariants that must change together. Enforce constraints and invariants in the
database where possible; application checks alone are not an integrity boundary.

Choose unique constraints, advisory locks, or row locks deliberately. Explain the
concurrency and isolation assumptions, including the behavior under competing writes,
retries, and reader visibility. Treat schema and migration risk as an explicit
compatibility concern.

## Migration and repair discipline

For compatible evolution, use expand, migrate, contract sequencing. Make an idempotent migration
and idempotent backfill where retries are possible. Define rollback when it is safe; otherwise
define forward repair and the evidence required before proceeding.

Inspect indexes and the query plan for changed access paths. Preserve RLS and tenant isolation,
including behavior for administrative and background access. Use deterministic DB tests for
constraints, transaction boundaries, concurrent transitions, and migration/backfill behavior.

No destructive operation proceeds without explicit authorization and proof of the
precise target, recovery path, and verification result. Report those facts in the
production-delivery handoff.
