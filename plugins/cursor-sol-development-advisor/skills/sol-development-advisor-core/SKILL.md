---
name: sol-development-advisor-core
description: Shared generic Sol Development Advisor policy used by every client adapter.
---

# Sol Development Advisor shared core

This document is the policy source of truth. Codex and Cursor adapters bind this
contract to their own execution surfaces; they do not redefine eligibility, risk,
delivery profiles, ownership, verification, or publication authority.

## Product identity

The product is **Sol Development Advisor**. **React Sol Advisor** is a legacy display
name and invocation alias. Both names resolve to the same generic implementation and
the same routing policy. The compatibility identifiers remain:

- repository: `AndersGerner/react-sol-advisor`
- plugin: `react-sol-advisor@react-sol-advisor`
- direct invocation: `@react-sol-advisor`

## Shared route declaration

Before a client-specific task, agent, or reviewer call, the parent emits one complete
route declaration. Model selection and delivery-profile selection are separate
decisions.

```text
ADVISOR ROUTE
CLIENT: codex | cursor
POLICY: economy | balanced | critical
RISK: green | amber | red
IMPLEMENTATION MODE:
- codex-luna-native
- codex-luna-detached
- codex-terra-native
- cursor-composer
- cursor-luna
- cursor-grok
- parent-only
- decomposed-mixed
REASONS:
- evidence from owned code and acceptance criteria
OWNERSHIP:
- exact paths, modules, or bounded responsibility
DELIVERY PROFILES:
- production-delivery always, plus selected conditional profiles
ESCALATION TRIGGERS:
- newly revealed ambiguity, ownership conflict, or risk boundary
REVIEW:
- parent verification and any required fresh Sol review
PR POLICY:
- none | commit-only | draft-after-acceptance
MODEL EVIDENCE:
- requested model/tier and independently observed model/tier, or unknown
```

There is no phrase-only client fallback. If the selected client, model, service tier,
role, or observation surface is unavailable, the parent reports the missing capability
and follows the declared policy's fail-closed rule.

## Eligibility and delivery profiles

Every implementation uses `production-delivery`. Add only the profiles required by
owned code and observable acceptance:

- `react-production-delivery` for React, Next.js, React Native, Expo, or UI behavior;
- `typescript-backend-delivery` for TypeScript service, API, event, mapper, or backend
  behavior;
- `postgres-data-delivery` for schema, query, transaction, persistence, or data
  invariants;
- `worker-integration-delivery` for provider, queue, worker, background, or external
  side-effect behavior.

Profiles compose. A missing React slice does not remove eligibility, add a confirmation
gate, or produce a blocked result. React is selected only for owned React/UI behavior.
The generic profile matrix is the authority for profile selection; risk classification
selects the lane after profiles are known.

## Risk and ownership

- Green means acceptance, architecture, ownership, bounded scope, tests, reversible
  blast radius, and no unresolved red trigger are all established.
- Amber means the parent can isolate independently green workstreams while a
  consistency, contract, or ambiguity core remains with the configured high lane.
- Red includes security, authorization, destructive data work, migrations, public
  contracts, incidents, native boundaries, or unresolved safety conflicts.

The parent owns architecture, decomposition, ownership boundaries, acceptance, Linear,
worktrees, publication, review, merge, closeout, and deployment boundaries. A worker or
reviewer never creates a hidden publication path.

## Verification and correction

Each implementation packet names exact owned and excluded paths, selected profiles,
acceptance criteria, and deterministic checks. The parent independently inspects the
complete diff and reruns the required verification. A correction uses the same declared
identity only when the specification was wrong or incomplete; unchanged prompts are not
retried. Newly revealed amber/red risk escalates immediately.

Critical work requires a fresh Sol review after parent verification. A reviewer returns
evidence-backed `ship`, `fix-first`, or `rethink`; requested read-only behavior is not
treated as proof of enforced isolation.

## Model evidence

Every route records `requested_model` and `observed_model` separately, plus requested
and observed service tier when relevant. Frontmatter, a role pin, a prompt, or a model
catalog entry proves only the requested binding. An observed value requires runtime
metadata or an explicit independent report. High-risk acceptance fails closed when the
actual model identity cannot be observed.
