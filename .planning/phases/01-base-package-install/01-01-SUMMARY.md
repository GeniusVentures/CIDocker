---
phase: 01-base-package-install
plan: 01
subsystem: infra
tags: [docker, dnf, almalinux, build-image, ci, glibc]

requires:
  - phase: null
    provides: null
provides:
  - Walking-skeleton almalinux-8/Dockerfile (base + ENV contract + ordered repo enablement + thin package slice)
  - SKELETON.md walking-skeleton architectural contract
affects: [02-toolchain-install, 03-parity-verification, 04-multiarch-verification]

tech-stack:
  added: [almalinux:8 base image, dnf, dnf-plugins-core, epel-release, powertools, gh-cli repo, NodeSource rpm repo, llvm-toolset module]
  patterns: [heredoc RUN + set -eux, repo-enablement-before-install, cache-cleanup-in-same-layer]

key-files:
  created: [almalinux-8/Dockerfile, .planning/phases/01-base-package-install/SKELETON.md]
  modified: []

key-decisions:
  - "AlmaLinux 8 base (glibc 2.28) with dnf as package manager"
  - "Ordered repo enablement: dnf-plugins-core → epel-release → powertools → gh-cli.repo → NodeSource → llvm-toolset"
  - "Walking-skeleton thin package slice (pkgconf-pkg-config sudo git wget curl jq) to prove the repo+install pipeline; full PKG-01 list deferred to Plan 02"

patterns-established:
  - "heredoc RUN + set -eux for multi-command layers; plain RUN for single commands"
  - "dnf clean all in the same RUN layer as every dnf install"

requirements-completed: [BASE-01, BASE-02]

coverage:
  - id: D1
    description: "Walking-skeleton almalinux-8/Dockerfile — FROM almalinux:8, ENV contract, six ordered repo/module enablement steps, thin package slice"
    requirement: "BASE-01"
    verification:
      - kind: manual_procedural
        ref: "grep static checks: line1 # syntax, line2 FROM almalinux:8, ordered steps, no --nogpgcheck/gpgcheck=0/crb"
        status: pass
    human_judgment: true
    rationale: "Runtime verification (docker build → ldd --version reports glibc 2.28; dnf repolist lists repos) is BLOCKED — Docker daemon is not running (human action to start Docker Desktop). Static Dockerfile criteria pass; runtime proof deferred until daemon is available."
  - id: D2
    description: "SKELETON.md walking-skeleton architectural contract with the five required sections and correct decisions"
    verification:
      - kind: manual_procedural
        ref: "grep: Capability Proven End-to-End / Architectural Decisions / Stack Touched in Phase 1 / Out of Scope / Subsequent Slice Plan present"
        status: pass
    human_judgment: true
    rationale: "Planning artifact whose correctness is judgment-dependent (architectural decision accuracy); no executable test asserts it."

duration: 10min
completed: 2026-09-08
status: complete
---

# Phase 1 Plan 1: Walking Skeleton Summary

**Walking-skeleton `almalinux-8/Dockerfile` (base + ENV + ordered repos + thin slice) and the SKELETON.md architectural contract.**

## Performance

- **Duration:** 10 min
- **Started:** 2026-09-08T22:50:00Z
- **Completed:** 2026-09-08T23:04:00Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- Created `almalinux-8/Dockerfile` starting `FROM almalinux:8` with the `debian-bullseye` ENV contract (RUSTUP_HOME/CARGO_HOME/PATH/RUST_VERSION) carried forward verbatim.
- Implemented all six ordered repo/module enablement steps (dnf-plugins-core → epel-release → powertools → gh-cli.repo → NodeSource → llvm-toolset) with `gpgcheck=1` preserved and no `--nogpgcheck`/`crb` tokens.
- Added the thin walking-skeleton package slice (pkgconf-pkg-config, sudo, git, wget, curl, jq) with same-layer `dnf clean all` + `rm -rf /var/cache/dnf`, marked for Plan 02 replacement.
- Finalized `SKELETON.md` with the five required sections and the pinned architectural decisions.

## Task Commits

Each task was committed atomically:

1. **Task 1: Create walking-skeleton almalinux-8/Dockerfile** - `c8429f7` (feat)
2. **Task 2: Write SKELETON.md walking-skeleton contract** - `b6139cf` (docs)

**Plan metadata:** committed with tracking files (see plan 01-01 metadata commit).

## Files Created/Modified
- `almalinux-8/Dockerfile` - Walking skeleton: base image, ENV contract, six ordered repo/module enablement layers, thin package slice with cache cleanup.
- `.planning/phases/01-base-package-install/SKELETON.md` - Walking-skeleton architectural contract (updated NodeSource URL mention to match acceptance criteria).

## Decisions Made
- Followed the plan and RESEARCH.md recipe exactly: `powertools` (not the 9-series repo id), NodeSource via `curl -fsSL` + delete-after-use, `dnf clean all` co-located with each install, `llvm-toolset` before any clang install.
- Rephrased a Dockerfile comment to avoid the literal `crb` string (the acceptance criterion forbids that token anywhere in the file).

## Deviations from Plan

None - plan executed as written. The Dockerfile was created exactly per the task action (single-line `dnf install` bodies in heredoc layers for steps 1/2/5, plain `RUN` for steps 3/4/6, heredoc thin slice).

## Issues Encountered

**Docker daemon not running** — the plan's Docker-dependent acceptance criteria (`docker build` exiting 0, `ldd --version` → 2.28, `dnf repolist` listing the seven repos) could not be executed. Static Dockerfile acceptance criteria (structure, ordering, forbidden tokens, all six steps, same-layer cleanup) all PASS. The runtime criteria are recorded as **blocked** (daemon start is a human action), not failed. Plan 02 re-runs the Docker build, which will re-exercise these criteria end-to-end.

## User Setup Required

None - no external service configuration required for this plan.

## Next Phase Readiness

- Ready for Plan 02 (full PKG-01 package set + in-image verification chain), which replaces the marked thin-slice block in `almalinux-8/Dockerfile`.
- **Blocker to resolve before final phase verification:** start the Docker daemon (Docker Desktop) so `docker build` / `ldd --version` / `dnf repolist` can be executed.

---
*Phase: 01-base-package-install*
*Completed: 2026-09-08*
