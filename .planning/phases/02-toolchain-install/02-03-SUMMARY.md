---
phase: 02-toolchain-install
plan: 03
subsystem: infra
tags: [docker, almalinux, build-image, ci, env-contract, runtime-glue, verification]

requires:
  - phase: 02-toolchain-install
    provides: mold + Node layers (Plan 01), Rust + JDK layers (Plan 02)
provides:
  - Final ENV contract (byte-for-byte bullseye parity) (TOOL-05)
  - Runtime glue: git safe.directory + seeded machine-id (PKG-02)
  - Phase 2 verification chain (authoritative gate)
affects: [03-parity-verification, 04-multiarch-verification]

tech-stack:
  added: [JAVA_HOME/JDK_HOME/JAVA_*_INCLUDE_PATH/JAVA_JVM_LIBRARY env vars, literal final PATH, dbus machine-id seeding]
  patterns: [bare ENV directive for env contract, two plain RUN glue layers, fail-fast verification heredoc]

key-files:
  created: [.planning/phases/02-toolchain-install/02-03-SUMMARY.md]
  modified: [almalinux-8/Dockerfile]

key-decisions:
  - "Final ENV block byte-for-byte from bullseye; PATH written literally (no :$PATH append) (D-07)"
  - "git config --system --add safe.directory '*' + machine-id seeded from /proc/sys/kernel/random/uuid and copied to /etc/machine-id (D-08/D-09)"
  - "Phase 2 verification chain asserts all five success criteria in one fail-fast layer"

patterns-established:
  - "ENV as a bare directive (image metadata), not a RUN/heredoc"
  - "Runtime glue as two separate plain RUNs (git config; machine-id seed) matching the analog for cache stability"
  - "Verification chain: grep -q probes + test/cmp assertions + env echo"

requirements-completed: [TOOL-05, PKG-02]

coverage:
  - id: D1
    description: "Final ENV contract matches bullseye (full JAVA_* set + literal PATH)"
    requirement: "TOOL-05"
    verification:
      - kind: manual_procedural
        ref: "grep: all JAVA_*/JDK_HOME vars + literal PATH present; final ENV PATH has no :$PATH (top ENV block untouched)"
        status: pass
    human_judgment: true
    rationale: "Static criteria pass. Runtime proof (image metadata + env echo) deferred to the consolidated build."
  - id: D2
    description: "Runtime glue: git safe.directory '*' + identical seeded machine-id"
    requirement: "PKG-02"
    verification:
      - kind: automated
        ref: "docker run --rm cidocker-almalinux-8:phase2 git config --system --get safe.directory -> '*'; sh -c 'cmp -s /var/lib/dbus/machine-id /etc/machine-id && echo identical' -> identical"
        status: pass
    human_judgment: false
    rationale: "Runtime proof confirmed. DEVIATION: on EL8 /var/lib/dbus/machine-id is a symlink to /etc/machine-id, so the bullseye cp is a self-copy error — seed /etc/machine-id directly instead."
  - id: D3
    description: "Verification chain asserts all five Phase 2 success criteria"
    requirement: "TOOL-01..TOOL-05, PKG-02"
    verification:
      - kind: automated
        ref: "docker build -t cidocker-almalinux-8:phase2 -f almalinux-8/Dockerfile . -> exits 0, all probes pass"
        status: pass
    human_judgment: false
    rationale: "Full build succeeded; verification chain (ld->mold 2.42.0, node->v24.x, rustc->1.87.0, java->Temurin-25, safe.directory->*, machine-id identical) all green."

duration: 10min
completed: 2026-09-08
status: complete
---

# Phase 2 Plan 3: ENV Contract + Runtime Glue + Verification Chain Summary

**Finalized `almalinux-8/Dockerfile` for Phase 2: byte-for-byte ENV contract, runtime glue, and the authoritative verification chain.**

## Performance

- **Tasks:** 3
- **Files modified:** 1 (`almalinux-8/Dockerfile`)

## Accomplishments
- **Final ENV (TOOL-05):** bare `ENV` directive mirroring bullseye byte-for-byte — `JAVA_HOME`, `JAVA_INCLUDE_PATH{,2}`, `JAVA_AWT_INCLUDE_PATH`, `JAVA_JVM_LIBRARY`, `JDK_HOME`, and the literal `PATH` (no `:$PATH` append). Top `ENV` block untouched.
- **Runtime glue (PKG-02):** `RUN git config --system --add safe.directory '*'` and `RUN mkdir -p /var/lib/dbus && cat /proc/sys/kernel/random/uuid | tr -d '-' > /etc/machine-id` (EL8-adapted — see Deviations).
- **Verification chain:** fail-fast heredoc asserting all five success criteria (`ld`→mold 2.42.0, `node`→v24.x, `rustc`→1.87.0, `java`→Temurin-25, `git safe.directory`→`*`, machine-id seeded + identical, env echo).

## Task Commits

1. **Task 1 + 2 + 3 (ENV + glue + verification chain)** - `3630a84` (feat)
2. **Fix: machine-id EL8 symlink** - `c869beb` (fix)

## Deviations

- **machine-id glue (PKG-02):** the plan's verbatim bullseye recipe (`cat ... > /var/lib/dbus/machine-id && cp /var/lib/dbus/machine-id /etc/machine-id`) FAILS on EL8 — the `almalinux:8` base ships `/var/lib/dbus/machine-id` as a **symlink to `/etc/machine-id`** (systemd convention), so `cp` is a self-copy error (`cp: '/var/lib/dbus/machine-id' and '/etc/machine-id' are the same file`). Fixed by seeding `/etc/machine-id` directly (the symlink keeps both paths identical automatically). Success criterion (both seeded + identical) still fully satisfied. This is a research gap in `02-RESEARCH.md` §6 — recorded for Phase 3 parity review.

## Self-Check: PASSED

`docker build -t cidocker-almalinux-8:phase2` exits 0; verification chain and explicit `docker run` probes confirm: mold 2.42.0, Node v24.20.0, rustc 1.87.0, Temurin 25.0.2, safe.directory `*`, machine-id identical, env contract literal PATH.
