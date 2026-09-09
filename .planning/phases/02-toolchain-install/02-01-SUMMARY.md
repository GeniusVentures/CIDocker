---
phase: 02-toolchain-install
plan: 01
subsystem: infra
tags: [docker, almalinux, build-image, ci, mold, nodejs, toolchain]

requires:
  - phase: 01-base-package-install
    provides: almalinux:8 base + dnf repos (incl. NodeSource) + full PKG-01 package set
provides:
  - mold 2.42.0 layer with update-alternatives ld shim (TOOL-01)
  - Node 24 layer via NodeSource rpm (TOOL-02)
affects: [02-02, 02-03]

tech-stack:
  added: [mold 2.42.0 (upstream static tarball), Node 24.x (NodeSource rpm)]
  patterns: [per-block uname -m case map, wget -q -> tar -> rm -> probe, same-layer dnf clean all]

key-files:
  created: [.planning/phases/02-toolchain-install/02-01-SUMMARY.md]
  modified: [almalinux-8/Dockerfile]

key-decisions:
  - "mold 2.42.0 via upstream static tarball + update-alternatives --install /usr/bin/ld ld /usr/local/bin/ld.mold 100 (GCC 8.5 cannot pass -fuse-ld=mold)"
  - "Node 24 rolling via 'dnf install -y nodejs' from the Phase-1-enabled NodeSource repo; no version pin (D-01/D-02)"
  - "Arch detection via full-string 'case \"$(uname -m)\" in' — x86_64/aarch64 only, hard exit 1 default (D-10)"

patterns-established:
  - "Toolchain tarball layer: RUN <<EOF + set -eux + case map + wget -q + tar --strip-components=1 + rm + probe"
  - "Node layer: dnf install -y nodejs && dnf clean all (same layer) + node --version + node -e 'process.exit(0)' probes"

requirements-completed: [TOOL-01, TOOL-02]

coverage:
  - id: D1
    description: "mold 2.42.0 installed as default ld via update-alternatives shim"
    requirement: "TOOL-01"
    verification:
      - kind: manual_procedural
        ref: "grep: moldVersion=\"2.42.0\", update-alternatives --install /usr/bin/ld ld /usr/local/bin/ld.mold 100, x86_64/aarch64 case arms, ld --version probe; no dpkg/armhf/i386"
        status: pass
    human_judgment: true
    rationale: "Static Dockerfile criteria pass. Runtime proof (docker build + ld --version -> mold 2.42.0) deferred to the consolidated build in plan 02-03 (single full build after all layers append)."
  - id: D2
    description: "Node 24 installed from NodeSource rpm with clean-exit probe"
    requirement: "TOOL-02"
    verification:
      - kind: manual_procedural
        ref: "grep: dnf install -y nodejs && dnf clean all, node --version, node -e 'process.exit(0)'; Node layer contains no repo setup"
        status: pass
    human_judgment: true
    rationale: "Static Dockerfile criteria pass. Runtime proof (node --version -> v24.x, clean exit) deferred to the consolidated build in plan 02-03."

duration: 10min
completed: 2026-09-08
status: complete
---

# Phase 2 Plan 1: mold + Node Layers Summary

**Appended the mold 2.42.0 and Node 24 toolchain layers to `almalinux-8/Dockerfile` (after Phase 1 step 9).**

## Performance

- **Tasks:** 2
- **Files modified:** 1 (`almalinux-8/Dockerfile`)

## Accomplishments
- **mold 2.42.0 (TOOL-01):** upstream static tarball downloaded from `github.com/rui314/mold/releases/v2.42.0`, extracted with `--strip-components=1` so `ld.mold` lands at `/usr/local/bin/ld.mold`, registered as default `ld` via `update-alternatives --install /usr/bin/ld ld /usr/local/bin/ld.mold 100`, probed with `ld --version`. Arch map: `x86_64`/`aarch64` via full `uname -m` string; hard `exit 1` default; no `dpkg`/`armhf`/`i386`.
- **Node 24 (TOOL-02):** `dnf install -y nodejs && dnf clean all` from the Phase-1-enabled NodeSource repo (rolling 24.x, no pin), probed with `node --version` and `node -e 'process.exit(0)'`.

## Task Commits

1. **Task 1 + 2 (mold + Node layers)** - `15c87e2` (feat)

## Deviations

- Docker-daemon-dependent acceptance criteria (`docker build` probes) deferred to the consolidated end-to-end build run during plan 02-03 (all layers append to the same file; a single full build exercises every layer and the authoritative 02-03 verification chain). No Dockerfile content deviation.

## Self-Check: PASSED

Static acceptance criteria (grep assertions) all pass; forbidden strings (`dpkg --print-architecture`, `${dpkgArch##*-}`, `armhf`, `i386`, deb NodeSource, `sudo apt`) absent from the new layers.
