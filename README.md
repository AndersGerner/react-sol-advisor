# Sol Development Advisor

Sol Development Advisor is a production delivery advisor for Codex. Every
implementation task carries the domain-neutral `production-delivery` core; React/UI,
TypeScript backend, Postgres/data, and worker/integration profiles are selected only
when their owned paths and observable acceptance require them. It routes eligible green
work through user-visible GPT-5.6 Luna / Max app tasks, escalates amber and red work to
a native GPT-5.6 Terra / High role, and requires a fresh Sol / High review at the
defined commitment boundaries.

The technical plugin identifier remains `react-sol-advisor`, and
`@react-sol-advisor` remains the legacy technical invocation for compatibility. React,
Next.js, React Native, and Expo delivery remain first-class specialist use cases; they
are no longer a prerequisite for backend, data, worker, or mixed delivery work.

This is a separately namespaced fork of the Sol Advisor project. Upstream attribution,
baseline SHA, and licensing are recorded in [UPSTREAM.md](UPSTREAM.md).

## What it does

- **Economy** (default): bounded green work -> Luna / Max; amber work -> Sol
  decomposition with Luna subparts and Terra core; red work -> Terra / High plus fresh
  Sol review.
- **Balanced**: green -> Luna / Max; amber -> Terra / High or `decomposed-mixed` only
  when every extracted Luna workstream independently passes all green criteria; red ->
  Terra / High plus fresh Sol review.
- **Critical**: green -> Terra / High unless a purely mechanical Luna subtask
  independently passes all green criteria; amber/red -> Terra / High.
  All critical work receives a mandatory fresh Sol review. That review runs after parent
  verification and includes any wholly or partly Luna-implemented mechanical diff.
- **No silent fallback**: if a lane is unavailable, report the missing capability and
  require explicit authorization before switching to a more expensive lane.
- **Delivery profiles**: `production-delivery` is mandatory for every implementation
  stream. React/UI, TypeScript backend, Postgres/data, and worker/integration profiles
  are conditional, composable, and selected from owned paths plus acceptance—not from
  risk or a blanket React assumption.
- **Optional Linear intake**: read-only issue normalization when a connector is
  available; full plugin usability from pasted requirements when it is not.
- **Capability-gated archiving**: archive accepted child tasks only when a supported
  operation exists, otherwise return a safe `THREADS_READY_TO_ARCHIVE` list.

## Installation

### Install from GitHub

Add the repository as a Codex marketplace and install the plugin:

```sh
codex plugin marketplace add AndersGerner/react-sol-advisor --ref main
codex plugin add react-sol-advisor@react-sol-advisor
```

Upstream Sol Advisor may remain installed as a separate plugin.

### Install native companion roles when needed

Green Luna-only work does not require native companion roles. Install them when you
want the Terra escalation lane or fresh Sol reviewer:

```sh
plugin_dir="$(
  codex plugin list --json |
    jq -r '.installed[] |
      select(.pluginId == "react-sol-advisor@react-sol-advisor") |
      .source.path'
)"

test -n "$plugin_dir"
test -d "$plugin_dir"

sh "$plugin_dir/scripts/install-agents.sh"
sh "$plugin_dir/scripts/install-agents.sh" --check
# Explicitly replace only the exact accepted 0.1.1 Terra/Sol pair:
sh "$plugin_dir/scripts/install-agents.sh" --upgrade-known
```

The installer:

- Installs only `react-sol-advisor-terra-implementer.toml` and
  `react-sol-advisor-sol-reviewer.toml`.
- Default install and `--check` never overwrite roles. `--upgrade-known` is the sole
  replacement path and accepts only the exact known 0.1.1 Terra/Sol pair; mixed,
  missing, modified, nonregular, symlinked, unreadable, and retired-Luna states fail
  before mutation.
- Stages both current templates, acquires one target-local ownership-verifiable upgrade
  lock before final classification, and tracks per-role publication ownership. A
  concurrent loser never rolls back the winner; rollback revalidates displaced content
  and restores unknown concurrent bytes without clobbering.
- Rolls back a failed pair replacement, removes owned lock/transaction artifacts, and
  is idempotent for an exact current/current pair. An unknown or stale lock fails closed
  for manual inspection rather than being removed automatically.
- Rejects the unsupported `react-sol-advisor-luna-implementer.toml`; Luna remains an
  app-task lane.
- Never creates native Luna or reads, changes, or deletes upstream companion-role
  files.

Start a **fresh Codex task** after installing or updating native roles so custom-agent
discovery sees the current profiles.

### Local checkout development

```sh
git clone https://github.com/AndersGerner/react-sol-advisor
cd react-sol-advisor
codex plugin marketplace add "$(pwd)"
codex plugin add react-sol-advisor@react-sol-advisor
```

## Usage

Use the plugin by mentioning the compatibility invocation `@react-sol-advisor` or
selecting the **Sol Development Advisor** skill in Codex. State the desired policy,
owned slice, and observable acceptance when they matter:

```text
@react-sol-advisor In this Next.js repository, add an accessible customer-status filter
that persists in the URL and follows the existing vehicle-filter implementation. Use
economy mode. Do not create a PR; leave an accepted commit and verification report.
```

For balanced or critical work, or to require a final Sol review, ask explicitly:

```text
@react-sol-advisor Implement FLE-789 using critical mode. This changes tenant
authorization and a shared API contract. Keep Sol on architecture, use Terra for
implementation, require a fresh Sol final review, and do not create a PR until the final
verdict is SHIP.
```

See [plugins/react-sol-advisor/examples/invocations.md](plugins/react-sol-advisor/examples/invocations.md)
for more invocation patterns and [plugins/react-sol-advisor/examples/luna-task-packet.md](plugins/react-sol-advisor/examples/luna-task-packet.md)
for an example Luna task packet.

## Routing policy

Before every delegation the primary session emits the following route block:

```text
ROUTING DECISION
POLICY: economy | balanced | critical
RISK: green | amber | red
LANE: luna-app-task | terra-native | sol-parent-only | decomposed-mixed
REASONS:
- concise evidence-based reason
OWNERSHIP:
- exact files/modules or bounded responsibility
DELIVERY PROFILES:
- production-delivery always, plus selected conditional specialist profiles
ESCALATION TRIGGERS:
- exact conditions that stop or change the lane
PR POLICY: none | commit-only | draft-after-acceptance
```

The full green/amber/red criteria and policy mapping are in
[plugins/react-sol-advisor/skills/orchestration/references/model-routing.md](plugins/react-sol-advisor/skills/orchestration/references/model-routing.md).

Representative non-React and mixed invocations retain the same compatibility command:

```text
@react-sol-advisor Add a pure deterministic TypeScript mapper with table-driven tests.
Use economy mode, production-delivery plus TypeScript backend, and leave an evidence
handoff without creating a PR.

@react-sol-advisor Add an idempotent tenant-safe Postgres backfill and verify its query
plan. Use production-delivery plus Postgres/data; do not select React for database-only
owned paths.

@react-sol-advisor Add retry classification and reconciliation for an established
provider worker. Use production-delivery plus worker/integration with deterministic
queue and provider fakes.

@react-sol-advisor Implement pg-boss admission, ownership, and orphan reconciliation.
Use the Postgres/data and worker/integration profiles. Decompose bounded helpers from
the Terra-owned consistency core; require a fresh Sol review if routing is red.

@react-sol-advisor Add a React URL filter and its established REST backend endpoint.
Split non-overlapping UI and backend workstreams; use profiles per workstream and do
not require the React profile for the backend-owned files.
```

## Luna task monitoring

Luna monitoring is capability-adaptive. When `wait_threads` is exposed with a usable
schema, the preferred path is `wait_threads -> read_thread -> independent child
worktree/diff verification`. `wait_threads` is preferred, not mandatory.

When `wait_threads` is absent, the supported fallback requires `list_projects`,
`list_threads`, `create_thread`, `read_thread`, and `send_message_to_thread`. It resolves
the real `threadId` and `hostId`, then uses bounded exact-thread
`read_thread(threadId, hostId)` polling. `list_threads` is used only for bounded identity
discovery when creation returned a setup handle, never as a post-identity completion
monitor.

Before creation, inspect the actual project and environment schemas. The proven
`list_projects` fields are `projectKind` and `supportsWorktrees`; do not rely on the
absent `isGitRepository` field. Independently confirm repository Git state and the exact
base/ref, and request `{type: "worktree"}` only when worktrees are explicitly supported.
If the schema exposes no safe environment for the exact project, fail closed.

The initial child packet contains only pre-creation values such as project identity,
returned schema fields, requested environment, base/ref, ownership, interfaces, and
verification. Real thread/host identity and monitoring mode are populated afterward in a
separate parent-owned lifecycle record. Those identities are sufficient to begin
monitoring while the child worktree remains unresolved. The first exact read, including
the read after `wait_threads`, may reveal the worktree; the parent then independently
verifies it and pins subsequent reads to that same worktree. Exact worktree evidence is
required before correction, acceptance, PR authorization, or dependent-task creation.
Existing identity belongs in a correction message, not the initial packet.

A turn is accepted only when its latest status is `completed`, a readable final
assistant handoff exists for that turn, the actual child worktree and complete diff have
been independently inspected, and parent-run verification passes. Thread `idle` is not
required; `active / completed` is valid when those gates pass. `idle` without a newly
completed turn and `notLoaded` are not completion evidence. Polling is bounded and fails
closed; there is no background callback.

Corrections reuse the same real thread, host, and child worktree, explicitly pass
`model = gpt-5.6-luna` and `thinking = max` on every correction call, record any returned
routing metadata, and must produce a new completed turn ID plus an updated handoff. If
`list_projects` does not return the exact intended path, add or open the folder as a
project in the Codex app and start a fresh task in that project. The plugin does not
invent project IDs, use Computer Use for registration, or substitute another repository.

## Native companion roles

The fork installs two custom-agent TOML files with pinned models and reasoning effort:

- `react_sol_advisor_terra_implementer` — GPT-5.6 Terra / High for the escalation
  implementation lane.
- `react_sol_advisor_sol_reviewer` — GPT-5.6 Sol / High, requested read-only, for fresh
  final review.

Do not add per-spawn model or reasoning overrides. Verify the actual role, model,
effort, sandbox, and permission profile before accepting native results. The host may
broaden the reviewer's requested sandbox; the parent must apply the behavioral
read-only rules in the orchestration contract rather than claiming enforced isolation.

## Verification

Run the complete local verification suite before accepting changes:

```sh
sh plugins/react-sol-advisor/scripts/verify.sh
sh plugins/react-sol-advisor/scripts/verify-hardening.sh
sh plugins/react-sol-advisor/scripts/verify-contracts.sh
sh plugins/react-sol-advisor/scripts/verify-luna-thread-contracts.sh
sh plugins/react-sol-advisor/scripts/verify-tmpdir-portability.sh
sh plugins/react-sol-advisor/scripts/verify-generalization.sh
sh plugins/react-sol-advisor/scripts/verify-agent-upgrade.sh
git diff --check
```

The GitHub Actions workflow runs all seven verifier scripts plus a base-to-head
whitespace check on pushes to `main` and `feat/*` branches and on pull requests targeting
`main`.

The suite checks:

- Manifest and marketplace identity
- Exact TOML role pins
- Installer path, symlink, conflict, rollback, and retired-Luna safety
- Runtime role/model/effort validation and observed isolation evidence
- Routing, production-delivery, and conditional specialist-profile contracts
- Safe known-version native-role upgrade, rollback, idempotence, and upstream/Luna
  non-interference
- Capability-adaptive Luna monitoring, exact-turn completion, correction identity,
  project registration, PR, and explicit archive evidence
- Optional Linear intake
- Stale identifiers and relative Markdown links

## Troubleshooting

- **Missing `wait_threads`**: use the bounded exact-thread `read_thread` fallback only
  when all five baseline app-task operations are exposed.
- **Missing fallback capability**: the plugin stops the Luna lane and reports the exact
  missing operation. Provide explicit authorization before switching to Terra.
- **Project path missing from `list_projects`**: add or open the folder as a project in
  the Codex app and start a fresh task in that project.
- **Unsafe project environment**: inspect the returned `projectKind`,
  `supportsWorktrees`, and `create_thread` environment schema; do not infer support from
  an absent field or invent a local fallback.
- **Stale native roles**: run `install-agents.sh --check` to detect missing, stale, or
  conflicting role files.
- **Retired native Luna file**: remove the namespaced
  `react-sol-advisor-luna-implementer.toml` manually; the installer will not delete a
  user-owned file.
- **Linear unavailable**: continue from pasted requirements; the plugin reports
  `LINEAR: unavailable; proceeded from supplied requirements`.
- **No archive operation**: the parent returns a `THREADS_READY_TO_ARCHIVE` list instead
  of simulating archive behavior.

## License

MIT. See [LICENSE](LICENSE) and [UPSTREAM.md](UPSTREAM.md) for attribution.
