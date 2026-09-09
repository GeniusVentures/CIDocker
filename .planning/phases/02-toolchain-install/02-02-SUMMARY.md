---
phase: 02-toolchain-install
plan: 02
subsystem: infra
tags: [docker, almalinux, build-image, ci, rust, temurin, jdk, toolchain]

requires:
  - phase: 02-toolchain-install
    provides: mold 2.42.0 + Node 24 layers (Plan 01)
provides:
  - Rust 1.87.0 via SHA256-pinned rustup 1.28.2 (TOOL-03)
  - Temurin JDK 25.0.2+10 via Adoptium tarball (TOOL-04)
affects: [02-03]

tech-stack:
  added: [Rust 1.87.0 (rustup 1.28.2, --profile minimal), Temurin JDK 25.0.2+10]
  patterns: [per-block uname -m case map, sha256sum -c pin check, dynamic JDK dir discovery, profile.d export block]

key-files:
  created: [.planning/phases/02-toolchain-install/02-02-SUMMARY.md]
  modified: [almalinux-8/Dockerfile]

key-decisions:
  - "Rust via rustup-init 1.28.2 --profile minimal --no-modify-path, SHA256-pinned per arch (D-03/D-04/D-05)"
  - "Temurin JDK 25.0.2+10 extracted to /usr/lib/jvm with temurin-25-jdk symlink + profile.d/java-env.sh (D-06)"
  - "armhf/i386/armv7/i686 branches deleted; x86_64/aarch64 only with hard exit 1 default (D-10)"

patterns-established:
  - "Rust layer: sha256sum -c pin check before chmod +x rustup-init; rustup-init writes into top-ENV RUSTUP_HOME/CARGO_HOME"
  - "JDK layer: dynamic extracted-dir discovery (tar -tzf | head -1 | cut -d/ -f1) then mv to temurin-25-jdk-{amd64|arm64} + ln -sfn symlink"

requirements-completed: [TOOL-03, TOOL-04]

coverage:
  - id: D1
    description: "Rust 1.87.0 installed via SHA256-pinned rustup, amd64+arm64 only"
    requirement: "TOOL-03"
    verification:
      - kind: manual_procedural
        ref: "grep: both rustup SHA256 pins, rustup-init --profile minimal, static.rust-lang.org URL, x86_64/aarch64 triples, chmod -R a+w; no armhf/i386 code arms"
        status: pass
    human_judgment: true
    rationale: "Static criteria pass. Runtime proof (rustc --version -> 1.87.0) deferred to the consolidated build in plan 02-03."
  - id: D2
    description: "Temurin JDK 25 installed under /usr/lib/jvm with symlink + profile.d"
    requirement: "TOOL-04"
    verification:
      - kind: manual_procedural
        ref: "grep: jdk-25.0.2+10, adoptium URL, dynamic extractedDir discovery, ln -sfn symlink, profile.d java-env.sh exports with escaped $JAVA_HOME; no armhf/i386 code arms"
        status: pass
    human_judgment: true
    rationale: "Static criteria pass. Runtime proof (java -version -> Temurin-25) deferred to the consolidated build in plan 02-03."

duration: 10min
completed: 2026-09-08
status: complete
---

# Phase 2 Plan 2: Rust + JDK Layers Summary

**Appended the Rust 1.87.0 and Temurin JDK 25 toolchain layers to `almalinux-8/Dockerfile` (after the Node layer).**

## Performance

- **Tasks:** 2
- **Files modified:** 1 (`almalinux-8/Dockerfile`)

## Accomplishments
- **Rust 1.87.0 (TOOL-03):** rustup-init 1.28.2 downloaded from `static.rust-lang.org` with per-arch SHA256 pin verification (`sha256sum -c`), `--profile minimal --no-modify-path`, default toolchain `$RUST_VERSION` (1.87.0), then `chmod -R a+w` on `$RUSTUP_HOME`/`$CARGO_HOME`. Arch map: `x86_64`/`aarch64` triples only; `armhf`/`i386` arms deleted.
- **Temurin JDK 25 (TOOL-04):** `OpenJDK25U-jdk_{x64,aarch64}_linux_hotspot_25.0.2_10.tar.gz` from Adoptium `jdk-25.0.2+10`, extracted with dynamic top-level-dir discovery, moved to `/usr/lib/jvm/temurin-25-jdk-{amd64,arm64}` with `temurin-25-jdk` symlink, plus `profile.d/java-env.sh` exports (`JAVA_HOME` literal + three `JAVA_*_INCLUDE_PATH` with escaped `$JAVA_HOME`).

## Task Commits

1. **Task 1 + 2 (Rust + JDK layers)** - `949c2c6` (feat)

## Deviations

- Docker-daemon-dependent acceptance criteria (`docker build` probes) deferred to the consolidated end-to-end build run during plan 02-03. No Dockerfile content deviation.

## Self-Check: PASSED

All static acceptance criteria pass; the only `armhf`/`i386` occurrences are the explanatory comments ("branches are deleted"), with no code arms present.
