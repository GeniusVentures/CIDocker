---
phase: 04-multi-arch-verification
plan: 01
subsystem: infra
tags: [github-actions, buildx, multi-arch, arm64, qemu, ghcr]

requires:
  - phase: 03-parity-verification
    provides: "verified almalinux-8 image (toolchain + behavior parity vs debian-bullseye)"
  - phase: 02-toolchain-install
    provides: "arch-clean Dockerfile (mold/Rust/JDK blocks with x86_64/aarch64 maps + exit 1 defaults)"
provides:
  - ".github/workflows/ci-almalinux.yml — multi-arch build/push + verification workflow"
  - "ghcr.io/geniusventures/almalinux-8:latest image reference (amd64 + arm64)"
affects: []

tech-stack:
  added: []
  patterns:
    - "buildx multi-arch push via docker/build-push-action@v7 (platforms: linux/amd64,linux/arm64)"
    - "QEMU-emulated arm64 smoke via docker/setup-qemu-action@v4 + docker run --platform linux/arm64"
    - "arch-clean grep gate (case-label token form (armhf|i386)\\)|armv7-unknown|i686-unknown + exit 1 >= 3)"

key-files:
  created:
    - .github/workflows/ci-almalinux.yml
  modified: []

key-decisions:
  - "Separate ci-almalinux.yml workflow (D-03) — ci.yml stays bullseye-only and untouched"
  - "Tag :latest only (D-02); no GH_TOKEN env and no strategy.matrix in the new workflow"
  - "Arch-clean gate uses case-label token form, not bare grep (avoids false-positive on Dockerfile's own 'deleted' comments)"

patterns-established:
  - "Manifest verification via docker buildx imagetools inspect --raw + grep for both architecture digests (no jq)"
  - "Pull-by-tag resolution inspects immediately after EACH pull (avoids local tag overwrite)"

requirements-completed: [BASE-03, PAR-03]

coverage:
  - id: D1
    description: "ci-almalinux.yml workflow — arch-clean gate (BASE-03) + multi-arch build/push (PAR-03)"
    requirement: "BASE-03"
    verification:
      - kind: other
        ref: "node static string assertions on .github/workflows/ci-almalinux.yml (Task 1 verify)"
        status: pass
    human_judgment: true
    rationale: "The definitive buildx push + arch-gate behavior runs in GitHub Actions on push — not locally verifiable on this Windows host."
  - id: D2
    description: "Verification chain — manifest inspect (PAR-03), pull-by-tag resolution, arm64 QEMU smoke (D-05/D-06)"
    requirement: "PAR-03"
    verification:
      - kind: other
        ref: "node static string assertions on .github/workflows/ci-almalinux.yml (Task 2 verify) + YAML parse (9 steps)"
        status: pass
    human_judgment: true
    rationale: "arm64 run smoke executes under QEMU in CI (D-05; no local QEMU on Windows, RESEARCH A2) — requires post-push observation of the Actions run."

duration: 15min
completed: 2026-09-09
status: complete
---

# Phase 4 Plan 1: Multi-arch Verification Summary

**Multi-arch sign-off workflow** — a new `ci-almalinux.yml` GitHub Actions workflow that builds and pushes `ghcr.io/geniusventures/almalinux-8:latest` for `linux/amd64` + `linux/arm64`, then statically gates out 32-bit arch references and verifies the push with manifest inspection, pull-by-tag resolution, and a QEMU-emulated arm64 smoke test.

## Performance

- **Duration:** ~15 min
- **Started:** 2026-09-09
- **Completed:** 2026-09-09
- **Tasks:** 2
- **Files modified:** 1 created (`.github/workflows/ci-almalinux.yml`)

## Accomplishments
- Created `.github/workflows/ci-almalinux.yml` — a 9-step workflow mirroring `ci.yml`'s login/QEMU/buildx/build-push sequence, hardcoding the Alma image (`context: almalinux-8`, `platforms: linux/amd64,linux/arm64`, `tags: ghcr.io/geniusventures/almalinux-8:latest`).
- Added the arch-clean gate (BASE-03/D-07): a `grep -nE '(armhf|i386)\)|armv7-unknown|i686-unknown'` assertion plus `grep -cE 'exit 1' … -ge 3`, using the case-label token form to avoid false-positives on the Dockerfile's own "branches deleted" comments.
- Added the verification chain: `imagetools inspect --raw` dual-digest assertion (PAR-03), pull-by-tag inspect-after-each-pull, and a QEMU arm64 `docker run` smoke covering all 14 tool probes (including `gnome-keyring`, `vulkan-headers`, `gh`).
- `ci.yml` remains byte-identical (`git diff --exit-code` clean) — bullseye and Alma push in parallel during the grace period.

## Task Commits

1. **Task 1: Create ci-almalinux.yml — arch-clean gate + multi-arch build/push** - `7a7f487` (ci)
2. **Task 2: Append manifest inspection, pull-by-tag, and arm64 run smoke** - `19f82c3` (ci)

## Files Created/Modified
- `.github/workflows/ci-almalinux.yml` — the multi-arch build/push + verification workflow (the phase's only artifact)

## Decisions Made
- Followed plan as specified — no deviations. Workflow filename `ci-almalinux.yml`, smoke probe set, and arch-clean grep expression applied exactly as locked in CONTEXT.md (D-01..D-07) and RESEARCH.md.

## Deviations from Plan

None - plan executed exactly as written.

## Verification

- Task 1 static assertions: PASS (all 15 required strings present; `ci.yml` byte-identical)
- Task 2 static assertions: PASS (all 19 required strings present)
- YAML validity: PASS (parses to 1 job, 9 steps)
- End-to-end CI proof (buildx push + arm64 smoke): **pending post-push human observation** — runs in GitHub Actions on next push (CI-only by design, D-05)

## Self-Check: PASSED

## Post-Push Human Verification

After pushing to GitHub, open the `ci-almalinux` workflow run:
1. `Build and push (multi-arch)` succeeds.
2. `Verify multi-arch manifest (PAR-03)` shows both `amd64` and `arm64` digests.
3. `Pull-by-tag resolution (amd64 + arm64)` shows `amd64` then `arm64`.
4. `arm64 run smoke test (full probe set)` passes all 14 probes with `uname -m` = `aarch64`.
