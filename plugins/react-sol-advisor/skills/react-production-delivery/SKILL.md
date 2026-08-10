---
name: react-production-delivery
description: >
  React, Next.js, React Native, Expo, and UI specialist delivery profile. Use with
  production-delivery for owned rendering, client/server, or native/JavaScript work.
---

# React production delivery profile

Use [production-delivery](../production-delivery/SKILL.md) for every implementation
task. Add this specialist profile only when an owned React, Next.js, React Native,
Expo, or UI path and its acceptance criteria require it. Non-React work does not load
this profile merely because it uses TypeScript.

## React pre-edit ownership

Before editing, identify component and state ownership; the server/client or native/JS
boundary; data-fetch and mutation ownership; UI loading, empty, error, success, and
retry behavior; accessibility behavior; async race, cancellation, and cleanup risk;
and public compatibility constraints. Return a blocker when these cannot be resolved
from the task and repository evidence rather than inventing a UI architecture.

## React architecture and rendering

Follow canonical component and rendering architecture from the repository. Keep domain
logic outside rendering components, preserve dependency direction, and maintain clear
client/server ownership for data, authorization, rendering, and mutations. For native
work, maintain the matching native/JavaScript boundary and platform ownership.

Keep form state, URL state, server state, durable client state, and transient UI state
separate. Derive values during rendering rather than synchronizing derived state in
effects. Use a new abstraction only when the owned behavior needs one or existing
architecture already owns it.

Server state remains in the repository's established server-state layer. Do not move it
into component-local state or duplicate it in another client cache without an explicit
repository convention that owns the synchronization.

## State, hooks, and effects

Keep hooks unconditional and dependencies correct. Use effects only to synchronize
with an external system; move interaction-specific behavior to event handlers. Use
functional state updates when the next value depends on prior state, and clean up
subscriptions, listeners, timers, observers, and async work exactly.

Prevent stale-result writes when inputs change quickly. Do not add memoization without
a structural or measured reason. Avoid defining unstable components inside components,
and use stable identity-based list keys.

## UI data and interaction behavior

Use the repository's established query and mutation layer and key conventions. Define
loading, empty, error, retry, and success UI behavior. Preserve cancellation or
stale-result protection where requests overlap, avoid duplicate destructive actions,
and define optimistic rollback and invalidation when optimistic behavior exists.

Parallelize independent UI data work and preserve ordering for dependent work. State
which request gates another request or mutation so rendering does not imply a false
ordering guarantee.

Treat authorization as a client/server boundary enforced by the server, not a UI-only
condition. Preserve repository error boundaries, telemetry, and user-safe diagnostics.

### React and TypeScript UI safety

Preserve strictness. Do not use `any` as an escape hatch; narrow `unknown` at external
boundaries. Use unsafe assertions only with a verified invariant, reuse canonical
domain types rather than duplicating shapes, and keep discriminated unions exhaustive.
Never manually edit generated or external types unless the repository explicitly
establishes that as its convention.

## Accessibility and platform behavior

Use semantic controls and accessible names, descriptions, states, and errors. Preserve
keyboard operation, focus order, visible focus, and intentional focus movement after
modal, removal, navigation, or validation changes. Do not rely on color alone; respect
reduced motion and dynamic text/font scaling. Test real interaction behavior, not only
static attributes. Use live regions only for meaningful asynchronous updates.

## Error handling, observability, and final inspection

Follow repository logging, analytics, and monitoring conventions. Never swallow
failures, avoid secrets or sensitive client logs, and distinguish user-recoverable
errors from developer diagnostics. Preserve correlation and metadata conventions when
reporting a client/server or native failure.

Before handoff, inspect the final React diff for accidental API changes, duplicate
logic, unsafe assertions, missing UI states, and unrelated changes.

## Conditional references

- Load [references/nextjs.md](references/nextjs.md) for App Router, server components,
  route handlers, server actions, caching, revalidation, streaming, metadata, or
  bundle boundaries.
- Load [references/react-native-expo.md](references/react-native-expo.md) for React
  Native, Expo, navigation, lists, animations, native APIs, lifecycle, linking,
  offline behavior, background work, or platform-specific UI.
- Load [references/testing-accessibility.md](references/testing-accessibility.md) for
  the testing contract, accessibility checklist, and verification order.

Do not apply generic framework advice without checking actual installed versions and
the repository's canonical implementation patterns.

## Conditional specialist selection

The [delivery profiles](../orchestration/references/delivery-profiles.md) matrix is the
mandatory canonical selection authority. It can require additional specialist skills
for the owned paths and acceptance criteria. Discover optional specialist skills by
their actual description and availability; do not assume a third-party skill name or
that a specialist is installed.
