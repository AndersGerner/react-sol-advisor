# React Sol Advisor build progress

This file is an execution ledger. Do not mark a deliverable complete until its command,
result, or explicit capability limitation is recorded below.

## Baseline

- [x] Current repository and remotes inspected
- [x] Upstream source URL recorded
- [x] Exact upstream HEAD SHA recorded
- [x] Difference from pack reference SHA assessed
- [x] Baseline verifier run before changes
- [x] Feature branch created

## Implementation tasks

- [x] Task 1 — establish fork identity, attribution, and namespace
- [x] Task 2 — create isolated namespaced native roles and safe installer
- [x] Task 3 — implement Luna-first orchestration and routing policy
- [x] Task 4 — implement React production-delivery skill and packet integration
- [x] Task 5 — implement task/thread lifecycle and capability-gated archiving
- [x] Task 6 — implement optional Linear intake
- [x] Task 7 — rewrite and expand repository verification
- [x] Task 8 — complete installation docs and usage examples
- [x] Task 9 — run the static scenario matrix and local installer/runtime fixtures
- [x] Task 10 — complete independent review, hardening fixes, and final CI verification

Live Codex app-task, native-agent, Linear, and archive-operation scenarios remain
capability-dependent and are listed explicitly under **Manual scenarios** rather than
being represented as executed.

## Decision log

| Date/time | Decision | Evidence | Consequence |
|---|---|---|---|
| 2026-08-06 | No subagent/worker available; execute initial tasks sequentially in parent | `which claude` failed, Ollama Gemma declined by user | Initial implementation and self-verification remained in one context |
| 2026-08-06 | Use `docs/react-sol-advisor-builder-pack/` as pack root | Pack is physically at that path | Root `BUILD-PROGRESS.md` is the live ledger |
| 2026-08-06 | Feature branch `feat/react-sol-advisor` from `154fd7ac` | `git checkout -b feat/react-sol-advisor` | Work isolated from `main` |
| 2026-08-06 | Marketplace advertises `react-sol-advisor` only | `.agents/plugins/marketplace.json` | Upstream plugin remains separately installable |
| 2026-08-07 | Treat model/effort as role pins and sandbox/permission as observed evidence | Reviewer sandbox can be broadened by the host | Inspector reports isolation; parent applies behavioral read-only policy |
| 2026-08-07 | Reject a namespaced native Luna companion instead of deleting it | Luna is an app-task lane and installed files are user-owned | Installer fails closed with zero partial role installation |
| 2026-08-07 | Treat critical as an explicitly expensive safety policy | Orchestration requires fresh Sol review for all critical work | Routing table, README, and plugin metadata now state the same guarantee |

## Review corrections

The original `FIX-FIRST` review on PR #1 identified six blocking findings. All are now
addressed:

- [x] Fresh Sol review is conditional on red/critical/consequential commitment boundaries.
- [x] Terra receives acceptance criteria, repository context, React quality contract, verification, and structured return.
- [x] Installer rejects root traversal and targets below symlinked ancestors.
- [x] Installer rollback is path-safe, including whitespace-containing targets and simulated second-file failure.
- [x] Runtime inspector enforces exact namespaced role/model/effort pins while reporting observed sandbox and permission evidence.
- [x] Verifiers cover positive and negative runtime mappings, missing evidence, multiple matches, rollback, symlink ancestors, retired Luna, and routing consistency.

Additional hardening completed during the second review:

- [x] Installer rejects the POSIX double-slash root alias before staging.
- [x] Balanced green work remains on Luna; Terra receives balanced amber/red work.
- [x] Expanded native packets are no longer described as “five-part.”
- [x] Default policy-selected Luna work is not described as separately opt-in.
- [x] Critical green/amber routing, README, and plugin metadata require fresh Sol review consistently.
- [x] Routing reference numbering is sequential.
- [x] README has copy-pasteable marketplace, plugin, companion, and verification commands.
- [x] GitHub Actions uses `actions/checkout@v6`, `contents: read`, full history, and a base-to-head whitespace gate.

## Verification log

| Scope | Command / evidence | Result |
|---|---|---|
| Baseline | `git rev-parse HEAD` | `154fd7ac282088f58246e192347960ba0bfc945f` |
| Repository verifier | `sh plugins/react-sol-advisor/scripts/verify.sh` | Pass |
| Installer/runtime hardening | `sh plugins/react-sol-advisor/scripts/verify-hardening.sh` | Pass |
| Routing contract consistency | `sh plugins/react-sol-advisor/scripts/verify-contracts.sh` | Pass |
| Whitespace | `git diff --check origin/main...HEAD` | Pass |
| CI | GitHub Actions run `31166694732` at `55c57b9411441f1b768d567754fee576f12b9bfa` | All four gates passed |
| Review | Independent second review of the full PR plus all repair deltas | `SHIP` |

The implementation/content head reviewed was `55c57b9411441f1b768d567754fee576f12b9bfa`.
This ledger update records evidence only and does not change plugin behavior.

## Manual scenarios

| Scenario | Expected behavior | Evidence / limitation |
|---|---|---|
| Bounded React component in economy mode | Luna / Max app task | Static routing and contract checks pass; live app-task tools unavailable in review environment |
| Next.js cache/revalidation ambiguity | Sol decomposes; Luna-safe subparts and Terra core | Static amber/decomposed-mixed policy verified |
| Auth or database contract change | Terra / High plus fresh Sol review | Static red/commitment-boundary policy verified |
| Critical-mode implementation | Terra / High by default; mandatory fresh Sol review | Orchestration, routing table, README, metadata, and contract checks agree |
| Luna app-task tools unavailable | Fail closed; no silent Terra fallback | Contract verified; live tool-unavailable path not exercised |
| Linear connector unavailable | Continue from pasted requirements when sufficient | Contract verified; live connector path not exercised |
| Archive operation unavailable | Return `THREADS_READY_TO_ARCHIVE` | Contract verified; live archive discovery not exercised |
| Correction required | Same Luna thread receives correction | Contract verified; live thread correction not exercised |
| Overlapping ownership | Serialize tasks | Contract verified; live concurrent worktrees not exercised |

## Final state

- [x] Repository verifier passes
- [x] Installer/runtime hardening verifier passes
- [x] Orchestration contract verifier passes
- [x] JSON manifests parse
- [x] TOML role files parse and match exact pins
- [x] Shell syntax checks pass
- [x] Base-to-head `git diff --check` passes
- [x] No stale plugin or role identifiers remain outside intentional attribution/coexistence locations
- [x] GitHub Actions passes on the reviewed implementation head
- [ ] Codex skill validator — unavailable in this environment
- [ ] Codex plugin validator — unavailable in this environment
- [x] Fresh reviewer verdict is `SHIP`

## Final review

```text
Reviewer: independent GPT-5.6 Pro review with GitHub diff inspection, failing regression tests, direct fixes, and CI
Base/head reviewed: 154fd7ac282088f58246e192347960ba0bfc945f..55c57b9411441f1b768d567754fee576f12b9bfa
Verdict: SHIP
Verification: repository, hardening, contract, and changed-range whitespace gates passed in GitHub Actions run 31166694732
Residual risk: live Codex Luna/Terra/Sol task routing, Linear, archive operations, and official Codex validators remain capability-dependent and were not exercised in this review environment
PR URL: https://github.com/AndersGerner/react-sol-advisor/pull/1
```

## 0.1.1 Luna exact-thread compatibility release

The live Codex compatibility probe supersedes the earlier React Sol Advisor limitation
that treated `wait_threads` as a hard Luna dependency. It changes only the namespaced
React Sol Advisor app-task monitoring contract. Native Terra/Sol routing, role pins,
installer behavior, runtime inspection, routing thresholds, critical-mode review, and
Linear write policy remain unchanged.

### Red-green cycle

| Phase | Command / evidence | Result |
|---|---|---|
| Red | `sh plugins/react-sol-advisor/scripts/verify-luna-thread-contracts.sh` before contract changes | Exit 1: `FAIL: wait_threads is preferred rather than mandatory` |
| Green | Same focused verifier after the capability-adaptive contract change | Exit 0: `LUNA THREAD CONTRACTS PASSED` |

### Live compatibility evidence

- Disposable Luna project, exact project/host/thread identities, both completed turn IDs,
  observed initial and follow-up transitions, child-worktree verification, and explicit
  archive acknowledgement are recorded in
  `docs/acceptance/2026-08-08-luna-read-thread-fallback.md`.
- Initial completion was observed as `idle / completed`; the same-thread follow-up was
  observed as `active / completed`, proving thread idle is not a success requirement.
- Both child artifacts were independently verified byte-exact in the actual detached
  child worktree before acceptance.
- `set_thread_archived` explicitly returned `archived = true`; later `notLoaded` state
  was not used as completion or archive evidence.

`EXACT_THREAD_POLLING_FALLBACK: SUPPORTED`

### Tracked-file search disposition

A tracked-file search for `wait_threads`, `wait/read`, `required app task tool`, and
`required capability` found contradictions in the React Sol Advisor contracts and
examples; those are updated by 0.1.1. The separately shipped upstream
`plugins/sol-advisor` plugin still documents its own mandatory `wait_threads` contract
and is intentionally unchanged because this compatibility release is scoped to
`plugins/react-sol-advisor`. Existing 0.1.0 build rows remain unedited historical
evidence; this section supersedes only their live Luna-monitoring limitation for the
React fork.

### 0.1.1 local verification

| Scope | Command | Result |
|---|---|---|
| Repository | `sh plugins/react-sol-advisor/scripts/verify.sh` | Exit 0: `VERIFY PASSED` |
| Hardening | `sh plugins/react-sol-advisor/scripts/verify-hardening.sh` | Exit 0: `HARDENING PASSED` |
| Existing contracts | `sh plugins/react-sol-advisor/scripts/verify-contracts.sh` | Exit 0: `CONTRACTS PASSED` |
| Exact-thread contracts | `sh plugins/react-sol-advisor/scripts/verify-luna-thread-contracts.sh` | Exit 0: `LUNA THREAD CONTRACTS PASSED` |
| TMPDIR portability | `sh plugins/react-sol-advisor/scripts/verify-tmpdir-portability.sh` | Exit 0: `TMPDIR PORTABILITY PASSED` |

The focused verifier also checks byte-identical SHA-256 values for both native role
files, `install-agents.sh`, and `inspect-agent-runtime.sh` against the required base.

### Review repair cycle

The post-implementation Sol review found three contract defects: the initial packet
required post-creation values, environment selection referenced an unexposed project
field, and corrections did not explicitly reassert Luna / Max. The repair preserves the
0.1.1 release scope and protected native subsystem.

| Phase | Command / evidence | Result |
|---|---|---|
| Red | Added review regression checks to `verify-luna-thread-contracts.sh` before changing the contracts | Exit 1: `FAIL: initial child packet is phase-separated from the parent lifecycle record` |
| Green | Same focused verifier after packet/lifecycle separation, schema-grounded environment selection, and correction-route pinning | Exit 0: `LUNA THREAD CONTRACTS PASSED` |

Repair details:

- The initial `create_thread` packet now contains only pre-creation project, environment,
  base, ownership, interface, constraint, and verification data.
- The parent lifecycle record is populated after creation with real thread, host,
  worktree, monitoring, routing, and completed-turn evidence.
- Environment selection uses returned `projectKind` and `supportsWorktrees`, independently
  confirms Git/base state, and requests `{type: "worktree"}` only when explicitly
  supported.
- Every same-thread correction call explicitly supplies `model = gpt-5.6-luna` and
  `thinking = max`, records returned routing metadata when present, and fails closed on a
  contradictory route.
