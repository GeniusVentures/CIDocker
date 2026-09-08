---
phase: 01-base-package-install
verified: 2026-09-08T23:08:50Z
status: human_needed
score: 3/6 must-haves verified
behavior_unverified: 1
behavior_unverified_items:
  - truth: "The full package set is verifiable in the built image (pkg-config --exists for vulkan/gtk3/libsecret, version commands)"
    test: "docker build -t cidocker-almalinux-8:phase1 -f almalinux-8/Dockerfile . then docker run --rm cidocker-almalinux-8:phase1 <check>"
    expected: "Build exits 0 and every version/pkg-config probe returns 0"
    why_human: "The verification chain exists in the Dockerfile but cannot be exercised — the Docker daemon is not running (human action to start Docker Desktop)."
---

# Phase 1: Base & Package Install Verification Report

**Phase Goal:** The `almalinux-8` image is based on AlmaLinux 8 (glibc 2.28) with every required EL8 system package installed from correctly-enabled repositories.
**Verified:** 2026-09-08T23:08:50Z
**Status:** human_needed

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Image is based on `almalinux:8` | ✓ VERIFIED | `almalinux-8/Dockerfile` line 2: `FROM almalinux:8` |
| 2 | All four non-default repos enabled in order (epel-release → powertools → gh-cli → NodeSource) after the dnf-plugins-core bootstrap, plus the llvm-toolset module | ✓ VERIFIED | Six ordered RUN layers present in sequence (bootstrap → epel → powertools → gh-cli → NodeSource → llvm-toolset); no `crb`/`--nogpgcheck`/`gpgcheck=0` |
| 3 | Every EL8 package in PKG-01 is installed in one dnf transaction | ✓ VERIFIED | Single `dnf install -y` heredoc layer with all 18 package lines; `dnf clean all` + `rm -rf /var/cache/dnf` in the same layer; `nodejs` absent |
| 4 | The full package set is verifiable in the built image (pkg-config --exists vulkan/gtk3/libsecret, version commands) | ⚠️ PRESENT_BEHAVIOR_UNVERIFIED | In-image verification chain present (`pkg-config --exists vulkan/gtk+-3.0/libsecret-1`, `rpm -q libatomic`, version commands) but not exercised — Docker daemon not running |
| 5 | `docker build` succeeds and the image reports glibc 2.28 via `ldd --version` | ? UNCERTAIN | `docker build` fails: cannot connect to dockerDesktopLinuxEngine pipe (daemon not running) |
| 6 | `dnf repolist` lists the enabled repos and `ruby --version` reports 3.1.x | ? UNCERTAIN | Requires a built image — blocked by daemon not running |

**Score:** 3/6 truths verified (1 present, behavior-unverified)

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `almalinux-8/Dockerfile` | Base + ENV + ordered repos + full PKG-01 + verification chain | ✓ EXISTS + SUBSTANTIVE | 84 lines; `FROM almalinux:8`, ENV contract, six repo layers, full package list, verification chain |
| `.planning/phases/01-base-package-install/SKELETON.md` | Walking-skeleton contract | ✓ EXISTS + SUBSTANTIVE | All five required sections present with correct decisions |
| `.planning/phases/01-base-package-install/01-01-SUMMARY.md` | Plan 01 summary | ✓ EXISTS | Complete |
| `.planning/phases/01-base-package-install/01-02-SUMMARY.md` | Plan 02 summary | ✓ EXISTS | Complete |

**Artifacts:** 4/4 verified

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|----|--------|---------|
| `almalinux-8/Dockerfile` | registry `almalinux:8` | `FROM` instruction | ✓ WIRED | Line 2: `FROM almalinux:8` |
| `almalinux-8/Dockerfile` | `dnf config-manager` | dnf-plugins-core bootstrap | ✓ WIRED | Bootstrap layer installs `dnf-plugins-core` before any `dnf config-manager` |
| `almalinux-8/Dockerfile` | built image | `docker build` + `ldd --version` | ? NOT VERIFIED | Blocked — Docker daemon not running |

**Wiring:** 2/3 connections verified

## Requirements Coverage

| Requirement | Status | Blocking Issue |
|-------------|--------|----------------|
| BASE-01: Image is based on `almalinux:8` (glibc 2.28) | ✓ SATISFIED (structural) | Runtime `ldd --version` → 2.28 needs human (Docker daemon) |
| BASE-02: dnf repositories enabled in order | ✓ SATISFIED | - |
| PKG-01: EL8 equivalents of every bullseye package | ✓ SATISFIED (structural) | In-image verification needs human (Docker daemon) |

**Coverage:** 3/3 requirements structurally satisfied (runtime proof pending human action)

## Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| - | - | None found | - | The Dockerfile contains no stubs, TODOs, `--nogpgcheck`, `gpgcheck=0`, or 9-series repo id |

**Anti-patterns:** 0 found

## Human Verification Required

### 1. Image builds and reports glibc 2.28
**Test:** Start Docker Desktop, then run `docker build -t cidocker-almalinux-8:phase1 -f almalinux-8/Dockerfile .` (expects exit 0), then `docker run --rm cidocker-almalinux-8:phase1 ldd --version | head -1`.
**Expected:** Build exits 0; output contains `2.28`.
**Why human:** Requires the Docker daemon, which is not running (starting it is a human action).

### 2. All repos are enabled in order
**Test:** `docker run --rm cidocker-almalinux-8:phase1 dnf repolist`.
**Expected:** Lists baseos, appstream, extras, epel, powertools, gh-cli, and a nodesource repo.
**Why human:** Requires a built image (Docker daemon).

### 3. Every PKG-01 package verifies in-image
**Test:** `docker run --rm cidocker-almalinux-8:phase1 pkg-config --exists vulkan` and `docker run --rm cidocker-almalinux-8:phase1 pkg-config --exists gtk+-3.0` (and libsecret-1), plus `docker run --rm cidocker-almalinux-8:phase1 ruby --version`.
**Expected:** All exit 0; `ruby --version` reports 3.1.x.
**Why human:** Requires a built image (Docker daemon).

### 4. Lean image (no dnf package cache)
**Test:** `docker images cidocker-almalinux-8:phase1 --format "{{.Size}}"`.
**Expected:** A reasonable size (dnf cache cleaned) comparable to `debian-bullseye`.
**Why human:** Requires a built image (Docker daemon).

## Gaps Summary

**No code gaps found.** All source artifacts are present and structurally correct. The only outstanding items are runtime verifications blocked by the Docker daemon not running (a human action). Once the daemon is started, the four items above can be confirmed via `/gsd-verify-work 1`.

## Verification Metadata

**Verification approach:** Goal-backward (derived from phase goal + plan must_haves)
**Must-haves source:** PLAN.md frontmatter (01-01-PLAN.md, 01-02-PLAN.md)
**Automated checks:** static Dockerfile criteria pass (structure, ordering, forbidden tokens, package list)
**Human checks required:** 4 (all blocked by Docker daemon)
**Total verification time:** ~5 min

---
*Verified: 2026-09-08T23:08:50Z*
*Verifier: Copilot (inline)*
