---
name: production-delivery
description: >
  Domain-neutral production delivery contract for every implementation task.
  Establishes scope, correctness, safety, verification, and evidence requirements.
---

# Production delivery contract

Use this contract for every implementation task, before adding any selected specialist
delivery profile. It is domain-neutral: it establishes the engineering baseline and
does not replace a profile that owns framework, persistence, or integration detail.

## Before implementation

1. Read applicable repository instructions and the task packet.
2. Inspect actual versions of the runtime, framework, package manager, and relevant
   dependencies; do not rely on generic latest-version advice.
3. Convert the request into observable acceptance criteria, including the behavior a
   user, caller, or operator can observe.
4. Find up to two canonical examples in the repository and state why they are the
   relevant examples.
5. State owned paths and excluded paths before editing. Preserve concurrent work and
   stop on an ownership overlap rather than widening scope.
6. Establish dependency and interface boundaries, public compatibility constraints,
   and the owner of each state transition or external side effect.
7. Define tests before implementation, then name the exact verification commands and
   expected evidence.

## Delivery behavior

Define success and failure behavior. When relevant to the task, explicitly define
retry, timeout, cancellation, rollback, recovery, and the behavior after a partial
failure. Classify failures as user-correctable, retryable, permanent, environmental,
or requiring an operator; do not hide an error by treating it as a successful result.

Preserve security, auth, privacy, and secrets boundaries. Do not expose credentials,
sensitive values, or internal diagnostics through an untrusted interface. Verify
authorization at the authority that owns it and preserve existing audit boundaries.

Protect data integrity under idempotency, concurrency, and recovery conditions. State
what happens on duplicate work, re-entry, interrupted work, and conflicting updates.
Use explicit error classification and observability so failures can be diagnosed with
safe context rather than reconstructed from guesswork.

## Types, scope, and implementation quality

Maintain strict typed safety. Narrow untrusted values at external boundaries, preserve
explicit invariants, and avoid unsafe assertions or `any` as an escape hatch. Keep
interfaces readable and preserve compatibility unless the task authorizes a change.

Make the smallest coherent diff. Do no cleanup unrelated to the request, do not invent
architecture when repository evidence is insufficient, and do not add abstractions
without a concrete ownership need. Keep implementation and tests inside the agreed
scope, then inspect the complete diff for accidental changes, missing cases, and
unintended interface changes.

## Verification and handoff

Run the exact verification defined before implementation. Report command output and
evidence, not only a conclusion. If a required check cannot run, state the blocker,
the affected acceptance criterion, and the strongest completed check.

Return this structured handoff:

```text
STATUS: complete | partial | blocked
OBJECTIVE: one-line outcome
ACCEPTANCE: each observable criterion with pass/fail evidence
FILES: actual changed and excluded paths
TESTS: tests added/changed and why
VERIFICATION: exact commands and concrete results
GIT: branch, base, changed files, commit state
JUDGMENT CALLS: material decisions and assumptions
GAPS: unfinished work, blockers, and next concrete step
```
