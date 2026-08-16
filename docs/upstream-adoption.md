# Upstream adoption ledger for 0.3.0

This fork inspected the listed upstream commits as implementation references. It did
not cherry-pick or merge them wholesale. Decisions below are bound to the local generic
core and deterministic verification.

Decision vocabulary is explicit: `adopted`, `adapted`, `rejected`, or `pending`. No
upstream change is treated as adopted merely because it was inspected.

| Upstream commit | Feature | Decision | Rationale | Local verification |
|---|---|---|---|---|
| `37b75cad535abdd46531f0227483a8842d045ab8` | risk-gated selective routing and role contracts | adapted | kept explicit route-before-delegation and risk gates; retained this fork's economy, generic profiles, and detached Fast lifecycle | cross-client oracle, existing routing verifiers, CI |
| `550ab1f71ae360c4adc733e572357bded7f70e5d` | native Luna / Max routine role and installer simplification | adapted | added the namespaced native Luna role but retained the fork's Fast honesty and detached lane; did not adopt upstream defaults or delete the validated lifecycle | native role/runtime verifier and three-role installer tests |
| `6f54e9fc43ddd385cd6c99f66caba5d852524aed` | simplified workflow and operations language | adapted | reused concise ownership/escalation discipline without replacing the shared profile matrix or parent authority | adapter contract checks |
| `ec15017c986118a5c077f347499a5e3920e1f163` | Agent Plugin package, schema tooling, and local Cursor helper | adapted | inspected schema and safe file-operation ideas; implemented the current official Cursor Plugin manifest and a narrower model-agent configuration flow with no MCP requirement | official-schema verifier and Cursor configuration acceptance |
| `91e2999ae6862f376317e9a0a5954ac72c5e0dfd` | revert of cross-client release | rejected as an implementation base | historical revert explains why the cross-client surface must be rebuilt deliberately; it is not a reason to discard the approved 0.3.0 architecture | current official Cursor repository/docs inspection and CI |

## Current upstream report

The current fetched upstream head and newer commits are reported by
`scripts/report-upstream.sh`. The report is read-only after fetch and never merges,
cherry-picks, or changes the local fork.
