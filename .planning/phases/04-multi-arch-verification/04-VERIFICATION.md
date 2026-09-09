---
phase: 04-multi-arch-verification
verified: 2026-09-09T00:00:00Z
status: human_needed
score: 2/5 must-haves verified
overrides_applied: 0
human_verification:
  - test: "After pushing to GitHub, open the `ci-almalinux` workflow run in Actions and confirm: (1) `Build and push (multi-arch)` succeeds; (2) `Verify multi-arch manifest (PAR-03)` shows both `amd64` and `arm64` digests; (3) `Pull-by-tag resolution (amd64 + arm64)` shows `amd64` then `arm64`; (4) `arm64 run smoke test (full probe set)` passes all 14 probes with `uname -m` = `aarch64`."
    expected: "The workflow run is green end-to-end; the OCI index at `ghcr.io/geniusventures/almalinux-8:latest` carries both `amd64` and `arm64` manifests; the arm64 container runs under QEMU and every tool probe passes."
    why_human: "This phase is CI-only by design (D-05). The definitive proof (buildx push, manifest digests, QEMU arm64 smoke) executes in GitHub Actions on the next push. There is no local QEMU on the Windows host (RESEARCH A2), so the end-to-end behavior cannot be verified programmatically here — only the static workflow content can be asserted."
---

# Phase 4: Multi-arch Verification Report

**Phase Goal:** The image is verified to build and run on `amd64` and `arm64` — and only those architectures.
**Verified:** 2026-09-09T00:00:00Z
**Status:** human_needed
**Re-verification:** No — initial verification

## Goal Achievement

This is a CI-only, config-only phase. The deliverable is a single new workflow file, `.github/workflows/ci-almalinux.yml`, whose end-to-end proof (buildx push + arm64 QEMU smoke) runs in GitHub Actions on push — not locally. Static-code must-haves were verified against the file content and the Dockerfile; CI-runtime must-haves are wired correctly but their runtime outcome requires human observation of the Actions run.

### Observable Truths

| #   | Truth   | Status     | Evidence       |
| --- | ------- | ---------- | -------------- |
| 1   | A single `ghcr.io/geniusventures/almalinux-8:latest` reference resolves to both `amd64` and `arm64` platform variants (ROADMAP SC-4) | ? UNCERTAIN | Static wiring present: `platforms: linux/amd64, linux/arm64`, `Verify multi-arch manifest (PAR-03)` asserts both digests, `Pull-by-tag resolution` inspects `= amd64` then `= arm64`. Actual resolution runs in Actions. |
| 2   | The image builds via `platforms: linux/amd64,linux/arm64` producing one OCI index with both digests (ROADMAP SC-1) | ? UNCERTAIN | `docker/build-push-action@v7` with `platforms: linux/amd64, linux/arm64` + `push: true`; `docker buildx imagetools inspect --raw` + dual-digest grep present. Push/manifest production runs in Actions. |
| 3   | The arch-clean gate fails the CI run if any `armhf`/`i386` branch label appears in `almalinux-8/Dockerfile` (ROADMAP SC-2 / BASE-03) | ✓ VERIFIED | Gate step present with case-label regex `(armhf\|i386)\)\|armv7-unknown\|i686-unknown` + `exit 1 ≥ 3` assertion. Dockerfile has **0** case-label matches and **3** `exit 1` defaults (mold/Rust/JDK blocks). |
| 4   | Every tool probe (rustc/node/java/mold/clang/cmake/gh/pkg-config + vulkan/gtk/libsecret/gnome-keyring/vulkan-headers) passes on `arm64` under QEMU (ROADMAP SC-3 / D-06) | ? UNCERTAIN | Smoke step present with all **14** probe strings; runs `docker run --rm --platform linux/arm64 ghcr.io/…`. Runtime pass happens only under QEMU in Actions. |
| 5   | `.github/workflows/ci.yml` remains byte-identical (bullseye-only); the new workflow coexists (D-03) | ✓ VERIFIED | `git diff --exit-code -- .github/workflows/ci.yml` = exit 0; `ci-almalinux.yml` is a separate file. |

**Score:** 2/5 truths verified (static); 3/5 require human observation of the Actions run (wired correctly, outcome pending).

### Required Artifacts

| Artifact | Expected    | Status | Details |
| -------- | ----------- | ------ | ------- |
| `.github/workflows/ci-almalinux.yml` | Multi-arch build/push + verification workflow (min 70 lines, 9 steps) | ✓ VERIFIED | 80 lines; 9 steps in required order; no debt markers; no `GH_TOKEN`, no `strategy.matrix`, no `load: true`. |

### Key Link Verification

| From | To  | Via | Status | Details |
| ---- | --- | --- | ------ | ------- |
| `Build and push (multi-arch)` step | `almalinux-8/Dockerfile` | `context: almalinux-8` | ✓ WIRED | `context: almalinux-8` present (resolves to `almalinux-8/Dockerfile`). |
| `Arch-clean gate (BASE-03)` step | `almalinux-8/Dockerfile` | grep on case labels | ✓ WIRED | Regex `(armhf\|i386)\)\|armv7-unknown\|i686-unknown` + `exit 1 ≥ 3` present and correct. |
| `arm64 run smoke test` step | `ghcr.io/geniusventures/almalinux-8:latest` | `docker run --rm --platform linux/arm64 …` | ✓ WIRED | Command present verbatim; runs the pushed tag, not a local build. |

### Data-Flow Trace (Level 4)

N/A — this phase produces a CI config file, not a component/page that renders dynamic data. The "data flow" is the workflow's step sequence, verified above via key links and step order (Checkout → Arch-clean gate → Login → QEMU → Buildx → Build-and-push → Manifest inspect → Pull-by-tag → Smoke).

### Behavioral Spot-Checks

SKIPPED — CI-only phase. The workflow's behavior executes in GitHub Actions on push; no local runnable entry point exists (no QEMU on Windows, RESEARCH A2).

### Probe Execution

N/A — no `scripts/*/tests/probe-*.sh` probes declared or conventional for this phase; the phase's verification chain is inline workflow steps.

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
| ----------- | ---------- | ----------- | ------ | -------- |
| BASE-03 | 04-01-PLAN.md | Image builds for `amd64` and `arm64` only (no `armhf`/`i386`) | ✓ SATISFIED (static) | `platforms: linux/amd64, linux/arm64` + arch-clean gate; Dockerfile 0 case-label matches, 3 `exit 1` defaults. |
| PAR-03 | 04-01-PLAN.md | Multi-arch build verified with `docker buildx --platform linux/amd64,linux/arm64` | ✓ SATISFIED (static) | `build-push-action@v7` multi-platform push + `imagetools inspect --raw` dual-digest + pull-by-tag + arm64 smoke. |

Both requirement IDs declared in PLAN frontmatter (`requirements: [BASE-03, PAR-03]`) are present in REQUIREMENTS.md. No orphaned requirements: REQUIREMENTS.md traceability maps exactly BASE-03 and PAR-03 to Phase 4; both are checked `[x]`.

### Anti-Patterns Found

None. No `TBD`/`FIXME`/`XXX`/`TODO`/`HACK`/`PLACEHOLDER` markers, no empty implementations, no hardcoded-empty data, no `GH_TOKEN` over-carry, no `strategy.matrix`, no `load: true` (which would conflict with multi-platform).

### Human Verification Required

### 1. Post-push `ci-almalinux` Actions run

**Test:** After pushing to GitHub, open the `ci-almalinux` workflow run in Actions and confirm: (1) `Build and push (multi-arch)` succeeds; (2) `Verify multi-arch manifest (PAR-03)` shows both `amd64` and `arm64` digests; (3) `Pull-by-tag resolution (amd64 + arm64)` shows `amd64` then `arm64`; (4) `arm64 run smoke test (full probe set)` passes all 14 probes with `uname -m` = `aarch64`.
**Expected:** The workflow run is green end-to-end; the OCI index at `ghcr.io/geniusventures/almalinux-8:latest` carries both `amd64` and `arm64` manifests; the arm64 container runs under QEMU and every tool probe passes.
**Why human:** CI-only by design (D-05). The definitive proof executes in GitHub Actions on push; no local QEMU exists on this Windows host (RESEARCH A2), so only static workflow assertions are verifiable here.

### Gaps Summary

No static gaps found. All 9 workflow steps are present in the required order with correct action versions, the arch-clean gate is correctly formed against a Dockerfile that is currently arch-clean (0 case-label matches, 3 hard `exit 1` defaults), `ci.yml` is byte-identical, and decisions D-01..D-07 are all honored. The three CI-runtime truths (manifest digests, per-arch pull resolution, arm64 QEMU smoke) are correctly wired but cannot complete until the next push — these are deferred to human observation of the Actions run, not failures.

---

_Verified: 2026-09-09T00:00:00Z_
_Verifier: the agent (gsd-verifier)_
