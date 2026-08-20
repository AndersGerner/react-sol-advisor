# Codex adapter

Codex is one execution binding for the shared Sol Development Advisor core. Read
`shared-core.md` and `delivery-profiles.md` first. This adapter never changes profile
selection and never makes React a prerequisite. `React Sol Advisor` remains only the
legacy product-name alias.

## Route binding

The parent emits this shared declaration before any Codex call:

```text
ADVISOR ROUTE
CLIENT: codex
POLICY: economy | balanced | critical
RISK: green | amber | red
IMPLEMENTATION MODE: codex-luna-native | codex-luna-detached | codex-terra-native | parent-only | decomposed-mixed
REASONS:
OWNERSHIP:
DELIVERY PROFILES:
ESCALATION TRIGGERS:
REVIEW:
PR POLICY:
MODEL EVIDENCE:
```

Before any Codex app-task or native-agent call, emit the shared declaration with
`CLIENT: codex` and one of:

- `codex-luna-detached` — the validated user-visible Luna app-task lane;
- `codex-luna-native` — the optional native Luna / Max / Fast role, only with exact
  runtime and service-tier evidence;
- `codex-terra-native` — the namespaced Terra / High implementation lane;
- `decomposed-mixed` — parent decomposition with independently eligible workstreams;
- `parent-only` — no auxiliary call is necessary or capability evidence is missing.

The route records `requested_model`, `observed_model`, `requested_service_tier`, and
`observed_service_tier`. Missing observation is reported as unknown, never inferred.

## Detached Luna lane

`codex-luna-detached` preserves the validated lifecycle:

1. inspect the live project and environment schema and verify the exact repository base;
2. set `gpt-5.6-luna`, Max reasoning, and the catalog-advertised Fast tier when the
   app-task schema exposes those setters;
3. create the task and retain its real thread and host identity;
4. prefer `wait_threads`, or use the bounded exact-thread `read_thread` fallback only
   when every proven fallback operation is present;
5. use the first exact read to discover and pin the actual child worktree;
6. require the latest completed turn and readable handoff, then inspect the complete
   child diff and rerun parent verification;
7. correct the same identity only with a new completed turn and new handoff;
8. archive only after explicit archive evidence is returned.

Fast is a service tier, not a property of the Luna model or prompt. If Fast cannot be
set and observed for the applicable call, stop with `LUNA FAST MODE: blocked`. Do not
silently switch between detached and native Luna, Terra, Sol, or another client.

## Native roles

The managed role namespace is:

- `react_sol_advisor_luna_implementer` — `gpt-5.6-luna` / `max` for bounded green work;
  Native Luna additionally pins `service_tier = "fast"`; the effective runtime tier
  must be observable as `fast` or `priority`;
- `react_sol_advisor_terra_implementer` — `gpt-5.6-terra` / `high` for escalation;
- `react_sol_advisor_sol_reviewer` — `gpt-5.6-sol` / `high` for fresh review.

Native Luna is eligible only when the exact role, model, effort, and effective service
tier are observable. The role applies production delivery and selected
`production-delivery` and conditional profiles, stays within ownership, stops on ambiguity or newly revealed risk,
and may make one corrected attempt for an incorrect specification. It never owns
architecture, PRs, merges, Linear, deployment, or external state.

Native Terra is the implementation substitute for amber/red or otherwise context-heavy
work. A fresh Sol reviewer is required for red and critical boundaries and includes any
auxiliary contribution in the inspected diff. The host may broaden a requested
read-only sandbox; runtime evidence and behavioral review remain separate facts.

## Parent authority

The Codex adapter does not own Leasio Dev Flow, Linear mutations, worktree publication,
review completion, merge, closeout, or deployment. The primary session remains the
outer owner of those boundaries and returns a complete evidence handoff.
