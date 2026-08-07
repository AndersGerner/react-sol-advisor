# React Sol Advisor

A Luna-first React, Next.js, React Native, Expo, and TypeScript delivery orchestrator
for Codex. It routes green work through user-visible GPT-5.6 Luna / Max app tasks,
escalates amber and red work to a native GPT-5.6 Terra / High role, and requires a
fresh Sol / High review at commitment boundaries.

This is a separately namespaced fork of the Sol Advisor project. Upstream attribution,
baseline SHA, and licensing are recorded in [UPSTREAM.md](UPSTREAM.md).

## What it does

- **Economy** (default): bounded green React work -> Luna / Max; amber work -> Sol
  decomposition with Luna subparts and Terra core; red work -> Terra / High plus fresh
  Sol review.
- **Balanced**: green -> Luna / Max; amber -> Terra / High or explicitly bounded Luna
  subparts; red -> Terra / High plus fresh Sol review.
- **Critical**: green -> Terra / High unless a purely mechanical Luna subtask is
  explicit; amber/red -> Terra / High and mandatory fresh Sol review.
- **No silent fallback**: if a lane is unavailable, report the missing capability and
  require explicit authorization before switching to a more expensive lane.
- **React production contract**: every delegated React task carries the core
  production-delivery rules, with conditional Next.js, React Native/Expo, and
  testing/accessibility references.
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
```

The installer:

- Installs only `react-sol-advisor-terra-implementer.toml` and
  `react-sol-advisor-sol-reviewer.toml`.
- Refuses modified, nonregular, symlinked, or partially unsafe destinations.
- Rejects the unsupported `react-sol-advisor-luna-implementer.toml`; Luna remains an
  app-task lane.
- Leaves upstream `sol-advisor-*` companion files untouched.

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

Use the plugin by mentioning `@react-sol-advisor` or selecting the **React Sol Advisor**
skill in Codex. State the desired policy when it matters:

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

Before every delegation the primary session emits a `ROUTING DECISION` block:

```text
ROUTING DECISION
POLICY: economy | balanced | critical
RISK: green | amber | red
LANE: luna-app-task | terra-native | sol-parent-only | decomposed-mixed
REASONS:
- concise evidence-based reason
OWNERSHIP:
- exact files/modules or bounded responsibility
QUALITY CONTRACT:
- selected React/platform references
ESCALATION TRIGGERS:
- exact conditions that stop or change the lane
PR POLICY: none | commit-only | draft-after-acceptance
```

The full green/amber/red criteria and policy mapping are in
[plugins/react-sol-advisor/skills/orchestration/references/model-routing.md](plugins/react-sol-advisor/skills/orchestration/references/model-routing.md).

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
git diff --check
```

The GitHub Actions workflow runs the three verifier scripts on pushes to `main` and
`feat/*` branches and on pull requests targeting `main`.

The suite checks:

- Manifest and marketplace identity
- Exact TOML role pins
- Installer path, symlink, conflict, rollback, and retired-Luna safety
- Runtime role/model/effort validation and observed isolation evidence
- Routing and React production-delivery contracts
- Luna lifecycle, correction, PR, and archiving boundaries
- Optional Linear intake
- Stale identifiers and relative Markdown links

## Troubleshooting

- **Missing Luna app-task tools**: the plugin stops the Luna lane and reports the
  missing capability. Provide explicit authorization before switching to Terra.
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
