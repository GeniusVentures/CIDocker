---
phase: 01-base-package-install
verified: 2026-09-08T23:20:23Z
status: passed
score: 6/6 must-haves verified
behavior_unverified: 0
---

# Phase 1: Base & Package Install Verification Report

**Phase Goal:** The `almalinux-8` image is based on AlmaLinux 8 (glibc 2.28) with every required EL8 system package installed from correctly-enabled repositories.
**Verified:** 2026-09-08T23:20:23Z
**Status:** passed

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Image is based on `almalinux:8` | ✓ VERIFIED | `almalinux-8/Dockerfile` line 2: `FROM almalinux:8` |
| 2 | All four non-default repos enabled in order (epel-release → powertools → gh-cli → NodeSource) after the dnf-plugins-core bootstrap, plus the llvm-toolset module | ✓ VERIFIED | Six ordered RUN layers present in sequence (bootstrap → epel → powertools → gh-cli → NodeSource → llvm-toolset); no `crb`/`--nogpgcheck`/`gpgcheck=0` |
| 3 | Every EL8 package in PKG-01 is installed in one dnf transaction | ✓ VERIFIED | Single `dnf install -y` heredoc layer with all 18 package lines; `dnf clean all` + `rm -rf /var/cache/dnf` in the same layer; `nodejs` absent |
| 4 | The full package set is verifiable in the built image (pkg-config --exists vulkan/gtk3/libsecret, version commands) | ✓ VERIFIED | In-image verification chain ran at build time; `pkg-config --exists vulkan/gtk+-3.0/libsecret-1` all exit 0; version commands pass |
| 5 | `docker build` succeeds and the image reports glibc 2.28 via `ldd --version` | ✓ VERIFIED | `docker build` exited 0; `ldd --version` → "ldd (GNU libc) 2.28" |
| 6 | `dnf repolist` lists the enabled repos and `ruby --version` reports 3.1.x | ✓ VERIFIED | `dnf repolist` lists appstream, baseos, epel, extras, gh-cli, nodesource, powertools; `ruby --version` → 3.1.7 |

**Score:** 6/6 truths verified

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
| `almalinux-8/Dockerfile` | built image | `docker build` + `ldd --version` | ✓ WIRED | Build exited 0; `ldd --version` → 2.28 |

**Wiring:** 3/3 connections verified

## Requirements Coverage

| Requirement | Status | Blocking Issue |
|-------------|--------|----------------|
| BASE-01: Image is based on `almalinux:8` (glibc 2.28) | ✓ SATISFIED | - |
| BASE-02: dnf repositories enabled in order | ✓ SATISFIED | - |
| PKG-01: EL8 equivalents of every bullseye package | ✓ SATISFIED | - |

**Coverage:** 3/3 requirements satisfied

## Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| - | - | None found | - | The Dockerfile contains no stubs, TODOs, `--nogpgcheck`, `gpgcheck=0`, or 9-series repo id |

**Anti-patterns:** 0 found

## Human Verification Required

None — all verifiable items were confirmed programmatically after the Docker daemon was started (build + `ldd --version` + `dnf repolist` + in-image `pkg-config` checks + `ruby --version`).

## Gaps Summary

**No gaps found.** Phase goal achieved. All source artifacts are present and the image builds and passes every runtime check.

## Verification Metadata

**Verification approach:** Goal-backward (derived from phase goal + plan must_haves)
**Must-haves source:** PLAN.md frontmatter (01-01-PLAN.md, 01-02-PLAN.md)
**Automated checks:** docker build + in-image verification chain + ldd/dnf repolist/pkg-config/ruby probes — all pass
**Human checks required:** 0
**Total verification time:** ~15 min

---
*Verified: 2026-09-08T23:20:23Z*
*Verifier: Copilot (inline)*
