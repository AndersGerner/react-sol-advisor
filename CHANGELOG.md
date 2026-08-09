# Changelog

All notable changes to React Sol Advisor will be documented in this file.

## 0.1.1 - 2026-08-08

### Changed

- Made `wait_threads` the preferred Luna monitor rather than a mandatory capability.
- Added the proven bounded exact-thread `read_thread(threadId, hostId)` polling fallback
  when all five baseline app-task operations are exposed.
- Defined latest-turn completion, readable handoff, active/completed acceptance,
  same-thread correction, exact-project registration, and explicit archive evidence.
- Split the pre-creation child packet from the parent-owned lifecycle record so initial
  task creation never depends on thread, host, worktree, monitoring, or turn values that
  do not exist yet.
- Grounded environment selection in the observed `projectKind` and
  `supportsWorktrees` schema, with `{type: "worktree"}` allowed only when explicitly
  supported.
- Required every correction call to reassert `gpt-5.6-luna` with `thinking = max` and
  record any returned routing metadata.
- Allowed real thread/host identity to begin monitoring while the child worktree remains
  unresolved, then required the first exact read to populate and pin the verified
  worktree before correction, acceptance, PR authorization, or dependent work.

### Added

- Added semantic contract coverage for the Luna exact-thread lifecycle and wired it into
  GitHub Actions.
- Added a non-secret live compatibility evidence record for the initial turn,
  same-thread follow-up, child-worktree verification, and archive acknowledgement.

## 0.1.0 - 2026-08-06

### Added

- Initial fork from `DannyMac180/sol-advisor` at upstream SHA `154fd7ac`.
- New `react-sol-advisor` plugin identity, marketplace entry, and `0.1.0` version.
- Namespaced native custom-agent TOML roles: `react-sol-advisor-terra-implementer` and `react-sol-advisor-sol-reviewer`.
- Namespaced installer and runtime inspector that refuse upstream `sol-advisor-*` files.
- Luna-first routing policy with `economy`, `balanced`, and `critical` delivery modes.
- React production-delivery skill and references for React, Next.js, React Native, and Expo.
- Capability-gated Luna task-lane lifecycle, correction, PR authorization, and archiving.
- Optional read-only Linear intake with fail-closed behavior.
- Repository-local verifier covering JSON, TOML, installer safety, runtime evidence, routing, React contract, Linear, lifecycle, stale identifiers, and shell syntax.
- `UPSTREAM.md`, updated `README.md`, and usage examples.
