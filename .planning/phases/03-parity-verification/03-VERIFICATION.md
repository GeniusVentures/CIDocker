---
phase: 03-parity-verification
slug: parity-verification
verified: 2026-09-09T00:00:00Z
status: human_needed
score: 4/4 must-haves verified
overrides_applied: 0
human_verification:
  - test: "Run `bash almalinux-8/verify-parity.sh` (Git Bash or WSL) with the Docker daemon running"
    expected: "Prints `PASS: stated-major matrix (rustc/node/java/mold) matches`, `PASS: behavioral fixture output identical`, the GTK/clang/Ruby drift evidence, and `ALL PARITY CHECKS PASSED`; exits 0 and writes `.planning/phases/03-parity-verification/03-PARITY-REPORT.md`"
    why_human: "Requires a live Docker daemon to build `almalinux-8` locally and pull `ghcr.io/geniusventures/debian-bullseye:latest` — the runtime matrix values and fixture build output cannot be produced by static analysis (D-01: manual sign-off)"
---

# Phase 3: Parity & Verification — Verification Report

**Phase Goal:** The AlmaLinux 8 image is verified to behave identically to `debian-bullseye` for the consuming builds.
**Verified:** 2026-09-09
**Status:** human_needed (4/4 success criteria verified statically; one manual runtime run remains)
**Re-verification:** No — initial verification

## Goal Achievement

Phase 3's deliverables are **verification evidence, not image layers** (locked D-01…D-09). Per D-01, the parity harness is run **manually** for sign-off. This report verifies the *static* deliverables are complete and correct (fixture files + content gates + harness syntax/stages/gates + no `fuse-ld` + Dockerfiles/`ci.yml` unmodified per D-02), and marks the runtime `bash almalinux-8/verify-parity.sh` execution as the single remaining human step.

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Toolchain version matrix matches bullseye (Rust 1.87.0, Node 24, JDK 25, mold 2.42.0) side-by-side | ✓ VERIFIED (static) | `verify-parity.sh` `matrix()` collects `rustc/node/java/mold`; the hard-gate loop compares exactly those four fields and `exit 1`s on mismatch (`FAIL: <field> mismatch — bullseye=<b> almalinux=<a>`). D-03 bar respected: node/java compared at major only (`cut -d. -f1` / `sed`), rustc/mold at exact `1.87.0`/`2.42.0`. Runtime values pending the manual run. |
| 2 | Representative sample build (minimal fixture) compiles + equivalent artifacts | ✓ VERIFIED (static) | All 4 fixture files exist, are non-empty, committed (`feat(03-01)`), and pass content gates. Harness Stage 2 `run_fixture()` builds+runs C++ (plain `clang++`), std-only Rust, Node/Java probes, and the GTK probe on both images via `docker run -v fixture:/src:ro`, then `diff -u`s stdout (`FAIL: behavioral fixture output differs` on non-empty diff). Runtime pending the manual run. |
| 3 | GTK 3.22 (EL8) vs 3.24 (bullseye) gap non-blocking (compile probe + grep) | ✓ VERIFIED (static + live evidence) | `gtk_probe.c` passes gates (`#include <gtk/gtk.h>`, `gtk_get_major_version`, no `gtk_init`). Harness compiles it with `cc … $(pkg-config --cflags --libs gtk+-3.0)` and prints `pkg-config --modversion gtk+-3.0` for both images. RESEARCH.md carries the **live 2026-09-09 grep** of `W:\gnus\GeniusNetwork`: GTK includes confined to `GeniusWallet` Flutter scaffolding (out of scope, D-05); **zero** hits in `SuperGenius`/`GeniusSDK`/`util`/`zkLLVM`/`TokenContracts`/`TestVMs`. |
| 4 | Clang 11→17 + Ruby 2.7→3.1 drift verified (documented accept-risk + cheap Ruby probe) | ✓ VERIFIED (static) | Harness Stage 3 prints `NOTE: clang 11 -> 17 is documented, accepted drift (D-08)` and `NOTE: ruby 2.7 (bullseye) -> 3.1 (EL8) is documented, accepted drift (D-09)`, and runs `ruby -e 'puts "ruby-ok #{RUBY_VERSION}"'` on both images. Runtime probe output pending the manual run. |

**Score:** 4/4 truths verified (all at static/by-construction level; the manual run is the final human sign-off, not a failed truth).

## Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `almalinux-8/verify-parity.sh` | Side-by-side parity harness (D-01) | ✓ VERIFIED | `bash -n` exit 0; committed (`feat(03-02)`); contains `set -euo pipefail`, `docker info` pre-flight, `matrix()`, `run_fixture()`, `fixture:/src:ro`, `CARGO_TARGET_DIR=/tmp/cargo_target`, `diff -u`, `gtk_probe.c`, `ruby -e`, both `documented, accepted drift` notes, `03-PARITY-REPORT.md` tee, `ALL PARITY CHECKS PASSED`; **no `fuse-ld`**. |
| `almalinux-8/fixture/cpp/main.cpp` | clang + mold behavioral proof (PAR-01) | ✓ VERIFIED | Non-empty; `cpp-ok`, `std::accumulate`, `std::vector`; no `fuse-ld`, no version macro. |
| `almalinux-8/fixture/rust/Cargo.toml` | std-only crate manifest | ✓ VERIFIED | `[package]` + `edition = "2021"`; no `[dependencies]` section (only the explanatory comment). |
| `almalinux-8/fixture/rust/src/main.rs` | Rust behavioral proof (PAR-01) | ✓ VERIFIED | Non-empty; `rust-ok`; `vec![1u64,…]` + `.iter().sum()`; no version string. |
| `almalinux-8/fixture/gtk_probe.c` | GTK header/lib resolution probe (PAR-02) | ✓ VERIFIED | Non-empty; `#include <gtk/gtk.h>` + `gtk_get_major_version`; no `gtk_init`. |
| `.planning/phases/03-parity-verification/03-PARITY-REPORT.md` | Durable run-time evidence | ⏳ PENDING | Generated by the harness via `tee "$REPORT"` at run time — produced by the manual run (D-01). |

## Key Link Verification

| From | To | Via | Status | Details |
|------|----|----|--------|---------|
| `verify-parity.sh` | `cidocker-almalinux-8:parity` / `ghcr.io/geniusventures/debian-bullseye:latest` | `docker build` / `docker pull` | ✓ WIRED | Defaults `ALMA_IMAGE`/`BULLSEYE_IMAGE`; ghcr tag matches `ci.yml` `tags:`; documented local-build fallback via `BULLSEYE_IMAGE` override. |
| `verify-parity.sh` | `almalinux-8/fixture` | `docker run -v …/fixture:/src:ro` | ✓ WIRED | Read-only mount + `-w /src`; C++/Rust build inside the image under test. |
| `verify-parity.sh` | `gtk3-devel` | `pkg-config --cflags --libs gtk+-3.0` | ✓ WIRED | GTK probe compile + `pkg-config --modversion gtk+-3.0` report. |
| `main.cpp` | mold via default-ld shim | plain `clang++` (no `-fuse-ld=mold`) | ✓ WIRED | `ld --version | grep -q mold` asserted before build; bullseye clang 11 compatibility preserved (Pitfall 1 / Pattern 4). |

## Data-Flow Trace (Level 4)

Not applicable — this phase produces a host-side verification harness and static fixture sources, not data-rendering components. The only "flow" (fixture stdout → `diff -u` → PASS/FAIL) is exercised at run time and is verified by construction in the script body.

## Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Harness syntax | `bash -n almalinux-8/verify-parity.sh` | exit 0 | ✓ PASS |
| C++ content gates | `test -s` + `cpp-ok`/`accumulate` present, `fuse-ld` absent | all present/absent | ✓ PASS |
| Rust content gates | `rust-ok` present, `edition = "2021"`, no `[dependencies]` | all correct | ✓ PASS |
| GTK content gates | `#include <gtk/gtk.h>` + `gtk_get_major_version` present, `gtk_init` absent | all correct | ✓ PASS |
| D-02 (no Dockerfile/CI edits) | `git status` + `git log` | only `.planning/ROADMAP.md` + `.planning/config.json` modified; last Dockerfile commits are Phase 2 | ✓ PASS |
| Runtime parity run | `bash almalinux-8/verify-parity.sh` | requires Docker + ghcr pull | ? SKIP → human |

## Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| PAR-01 | 03-01, 03-02 | Same toolchain versions as bullseye (Rust 1.87.0, Node 24, JDK 25, mold 2.42.0) | ✓ SATISFIED (static) | Stage 1 matrix hard-gate on exactly those 4 fields; Stage 2 fixture proves clang/mold/Rust actually build and behave identically. Runtime confirmation is the manual run. |
| PAR-02 | 03-01, 03-02 | GTK 3.22-vs-3.24 gap verified non-blocking | ✓ SATISFIED | `gtk_probe.c` compile probe + live monorepo grep (RESEARCH.md): GTK includes only in out-of-scope Flutter scaffolding. |

**Orphaned requirements:** none — REQUIREMENTS.md maps exactly PAR-01/PAR-02 to Phase 3 (PAR-03 is Phase 4).

## Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| — | — | none | — | No `TODO`/`FIXME`/`XXX`/`PLACEHOLDER`, no `gtk_init`, no `__VERSION__`, no `[dependencies]`, no `-fuse-ld=mold` in any Phase 3 deliverable. The sole `fuse-ld` hit is the Phase-2 explanatory comment in `almalinux-8/Dockerfile` (unmodified, D-02). |

## Human Verification Required

### 1. Manual parity harness run (D-01 sign-off)

**Test:** Run `bash almalinux-8/verify-parity.sh` from the repo root in Git Bash or WSL, with Docker Desktop running and (for the default bullseye path) access to `ghcr.io/geniusventures/debian-bullseye:latest`.
**Expected:** Stage 1 prints `PASS: stated-major matrix (rustc/node/java/mold) matches`; Stage 2 prints `PASS: behavioral fixture output identical`; Stage 3 prints the GTK version pair, the monorepo grep verdict (non-blocking), the `ruby -e` output, and both `documented, accepted drift` notes; final line `ALL PARITY CHECKS PASSED` and a written `03-PARITY-REPORT.md`.
**Why human:** Requires a live Docker daemon to build the Alma image and pull the frozen bullseye image; runtime matrix values and fixture build output are not statically derivable. If `docker pull` fails (private ghcr tag), build locally with `docker build -t cidocker-debian-bullseye:parity -f debian-bullseye/Dockerfile .` and re-run with `BULLSEYE_IMAGE=cidocker-debian-bullseye:parity`.

## Gaps Summary

No blocking gaps. All 4 success criteria are met at the static/by-construction level:

- The fixture (03-01) and the harness (03-02) exist, are committed, are `bash -n`-clean, pass every content gate, and implement the exact comparison bars locked in D-03/D-06/D-07/D-08/D-09.
- PAR-02 carries the strongest evidence: the GTK grep was already run live (RESEARCH.md) and is conclusive.
- D-02 holds: `ci.yml`, `debian-bullseye/Dockerfile`, and `almalinux-8/Dockerfile` are untouched by Phase 3 (last Dockerfile commits are Phase 2).

The only remaining item is the **manual run** of `verify-parity.sh` to produce the runtime matrix + fixture-diff evidence and `03-PARITY-REPORT.md` (D-01). Once that run prints `ALL PARITY CHECKS PASSED`, the phase is fully signable and the status advances to `passed`.

Out-of-scope (post-milestone, not gaps): the thirdparty-CI "final verification" branch and the wallet-core Ruby behavioral check — both deferred by the user in DISCUSSION-LOG, outside any roadmap phase.

---

_Verified: 2026-09-09_
_Verifier: the agent (gsd-verifier)_
