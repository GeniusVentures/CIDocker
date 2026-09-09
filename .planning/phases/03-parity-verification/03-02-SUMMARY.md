---
phase: 03-parity-verification
plan: 02
subsystem: infra
tags: [docker, almalinux, parity, verification, harness, mold, rust, node, gtk]

requires:
  - phase: 03-parity-verification
    provides: almalinux-8/fixture/ (cpp, rust, gtk_probe)
  - phase: 02-toolchain-install
    provides: almalinux:8 image with full toolchain
provides:
  - almalinux-8/verify-parity.sh (side-by-side parity harness, D-01)
affects: []

tech-stack:
  added: []
  patterns: [fail-fast version-matrix gate, behavioral stdout diff, report-only drift evidence]

key-files:
  created:
    - almalinux-8/verify-parity.sh
    - .planning/phases/03-parity-verification/03-02-SUMMARY.md
  modified: []

key-decisions:
  - "Harness run MANUALLY (D-01); ci.yml and both Dockerfiles untouched (D-02)"
  - "Version matrix hard-gates exactly rustc/node/java/mold at stated majors (D-03); node patch may differ"
  - "Behavioral fixture diff (cpp-ok 15 / rust-ok 15 / node-ok / java-ok / gtk-ok) via diff -u (D-06); no byte-identity"
  - "clang 11->17 documented accepted drift (D-08); ruby 2.7->3.1 documented + ruby -e probe (D-09)"
  - "GTK: in-image compile probe + host monorepo grep (D-07); report-only, zero-match non-fatal"

patterns-established:
  - "Stages: acquire images -> matrix + hard gate -> behavioral diff -> drift evidence -> ALL PARITY CHECKS PASSED"
  - "Report tee: main() 2>&1 | tee 03-PARITY-REPORT.md"

requirements-completed: [PAR-01, PAR-02]

coverage:
  - id: D1
    description: "verify-parity.sh with Stage 1 stated-major version-matrix gate (PAR-01/D-03)"
    requirement: "PAR-01"
    verification:
      - kind: manual_procedural
        ref: "bash -n exit 0; grep: set -euo pipefail, docker info, matrix(), rustc, pkg-config --modversion gtk+-3.0"
        status: pass
    human_judgment: true
    rationale: "Script syntax + content gates pass. Runtime sign-off (docker build/pull + matrix + fixture) is a manual run per D-01."
  - id: D2
    description: "Stage 2 behavioral fixture diff + Stage 3 drift evidence (PAR-01/PAR-02)"
    requirement: "PAR-02"
    verification:
      - kind: manual_procedural
        ref: "grep: run_fixture(), fixture:/src:ro, CARGO_TARGET_DIR=/tmp/cargo_target, diff -u, gtk_probe.c, ruby -e, documented accepted drift, ALL PARITY CHECKS PASSED; no fuse-ld"
        status: pass
    human_judgment: true
    rationale: "Script content gates pass. Runtime proof requires Docker + ghcr pull of the frozen bullseye image (manual sign-off per D-01)."

duration: 15min
completed: 2026-09-09
status: complete
---

# Phase 3 Plan 2: verify-parity.sh Harness Summary

## What was built

`almalinux-8/verify-parity.sh` — the versioned, manually-run parity harness (D-01). It:

1. **Acquires images** — builds `cidocker-almalinux-8:parity` from the committed Dockerfile and pulls the frozen `ghcr.io/geniusventures/debian-bullseye:latest` (with a documented local-build fallback via `BULLSEYE_IMAGE`).
2. **Stage 1 (PAR-01 / D-03)** — prints a `key=value` matrix for both images and hard-gates the four stated majors (`rustc` 1.87.0, `node` 24, `java` 25, `mold` 2.42.0); `clang`/`cmake`/`ruby`/`gtk`/`glibc` are reported only.
3. **Stage 2 (PAR-01 / D-06)** — builds+runs the fixture on both images (C++ via clang+mold, std-only Rust, Node/Java probes, GTK compile probe) and `diff -u`s the stdout.
4. **Stage 3 (PAR-02 / D-07/D-08/D-09)** — `ruby -e` probe + documented 2.7→3.1 drift, documented clang 11→17 accept-risk, GTK version + host monorepo grep (report-only).
5. Writes `.planning/phases/03-parity-verification/03-PARITY-REPORT.md` via `tee` and ends with `ALL PARITY CHECKS PASSED`.

## Verification

- `bash -n almalinux-8/verify-parity.sh` → exit 0 (syntax valid).
- All content gates pass: `set -euo pipefail`, `docker info` pre-flight, `matrix()`, `run_fixture()`, `fixture:/src:ro`, `CARGO_TARGET_DIR=/tmp/cargo_target`, `diff -u`, `gtk_probe.c`, `ruby -e`, `documented, accepted drift`, `03-PARITY-REPORT.md`, `ALL PARITY CHECKS PASSED`.
- No `fuse-ld` reference in the script (Pitfall 1).
- `ci.yml`, `debian-bullseye/Dockerfile`, `almalinux-8/Dockerfile` remain unmodified (D-02).

**Manual sign-off (D-01):** run `bash almalinux-8/verify-parity.sh` (Git Bash/WSL) to produce the runtime parity evidence.
