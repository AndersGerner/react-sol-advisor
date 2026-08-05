---
name: react-production-delivery
description: >
  Production delivery contract for React, Next.js, React Native, Expo, and TypeScript.
  Enforces repository alignment, behavioral acceptance, state/effect correctness,
  accessibility, tests, focused scope, and evidence-backed verification.
---

# React production-delivery contract

Use this skill when implementing, fixing, refactoring, or reviewing React, Next.js,
React Native, Expo, or TypeScript UI code. It establishes a mandatory
senior-engineering workflow and loads focused references only when the task requires
them.

## Pre-edit requirements

Before editing, the worker must:

1. Read applicable repository instructions.
2. Inspect actual framework and package versions.
3. Convert the request into observable acceptance criteria.
4. Find up to two canonical repository examples and explain why they are relevant.
5. Identify:
   - Component and state ownership
   - Server/client or native/JavaScript boundaries
   - Data-fetching and mutation ownership
   - Loading, empty, error, success, and retry behavior
   - Accessibility behavior
   - Async race, cancellation, and cleanup risk
   - Public compatibility constraints
6. Name the expected changed-file scope.
7. Define focused tests and verification before implementation.
8. Return a blocker instead of inventing architecture when these cannot be resolved.

## Core implementation rules

### Architecture and separation of concerns

- Follow canonical repository architecture over generic personal preference.
- Keep domain logic out of rendering components.
- Keep server state in the repository's established server-state layer.
- Keep form state, URL state, server state, and durable client state separate.
- Preserve dependency direction and package boundaries.
- Introduce a new abstraction only when the task requires it, an existing abstraction
  should own the behavior, or concrete duplication would otherwise be created.
- Preserve public APIs unless the packet explicitly authorizes a change.

### State, hooks, and effects

- Derive values during render instead of synchronizing derived state through effects.
- Use effects only to synchronize with external systems.
- Keep hooks unconditional and dependencies correct.
- Move interaction-specific logic to event handlers.
- Use functional state updates when the next state depends on the prior state.
- Clean up subscriptions, listeners, timers, observers, and async work exactly.
- Avoid stale-response writes and race conditions where requests can overlap.
- Do not add memoization without a concrete measured or structural reason.
- Do not define components inside components when it causes unstable identity.
- Use stable identity-based list keys.

### Async data and mutations

- Use the repository's established query/mutation library and key conventions.
- Parallelize independent work; preserve required ordering for dependent work.
- Define loading, empty, error, retry, and success behavior explicitly.
- Prevent duplicate destructive actions.
- Handle optimistic updates with rollback and invalidation semantics when used.
- Treat authorization as a server-side boundary, not a UI condition.
- Preserve cancellation or stale-result protection where the user can change inputs
  quickly.

### TypeScript

- Preserve strictness.
- Do not use `any` to bypass a design problem.
- Narrow `unknown` at system boundaries.
- Avoid unsafe assertions unless a runtime invariant is verified and documented.
- Reuse canonical domain types rather than duplicating shapes.
- Keep discriminated unions exhaustive.
- Ensure generated and external types are not edited manually unless the project
  explicitly does so.

### Accessibility

- Prefer native semantic elements and platform controls.
- Provide accessible names, descriptions, states, and errors.
- Preserve keyboard operation, focus order, and visible focus.
- Restore or move focus intentionally after modal, removal, navigation, and
  validation events.
- Use live regions only for meaningful asynchronous updates.
- Respect reduced motion and dynamic text/font scaling where applicable.
- Do not rely on color alone.
- Test the actual interaction, not only static attributes.

### Error handling and observability

- Follow repository error boundaries, logging, analytics, and monitoring conventions.
- Do not swallow failures.
- Avoid leaking secrets or sensitive data into client logs.
- Distinguish user-facing recoverable errors from developer diagnostics.
- Preserve correlation and metadata conventions when present.

### Scope discipline

- Make the smallest coherent change.
- Do not mix unrelated cleanup or formatting into the feature.
- Preserve concurrent work.
- Do not edit outside owned files without returning a blocker.
- Inspect the final diff for accidental API changes, duplicate logic, unsafe
  assertions, missing states, and unrelated changes.

## Conditional references

- Load [references/nextjs.md](references/nextjs.md) when the task involves App Router,
  server components, route handlers, server actions, caching, revalidation, streaming,
  metadata, or bundle boundaries.
- Load [references/react-native-expo.md](references/react-native-expo.md) when the
  task involves React Native, Expo, navigation, lists, animations, native APIs, app
  lifecycle, linking, offline behavior, background work, or platform-specific UI.
- Load [references/testing-accessibility.md](references/testing-accessibility.md) for
  the testing contract, accessibility checklist, and verification order.

Do not apply generic "latest" framework advice without checking the repository version
and current official documentation.

## Specialist skill selection

The parent may discover installed specialist skills by description and select only those
relevant to the task, for example:

- React/Next performance
- Expo Router/native UI
- React Native performance
- Data fetching
- Accessibility
- Testing

The task packet records which skills were selected. Do not assume a third-party skill
name or availability. The core contract in this plugin remains the fallback and cannot
be omitted.

## Structured worker return

```text
STATUS: complete | partial | blocked
OBJECTIVE: one-line outcome
ACCEPTANCE: each criterion with pass/fail evidence
CANONICAL EXAMPLES: paths used
CHANGES: file-by-file summary from actual diff
TESTS: tests added/changed and why
VERIFIED: exact commands and concrete results
GIT: branch, base, changed files, commit state
JUDGMENT CALLS: decisions left open by packet, or none
GAPS: unfinished work, blockers, or none
```
