---
phase: 03-parity-verification
plan: 01
subsystem: infra
tags: [docker, almalinux, parity, fixture, clang, mold, rust, gtk]

requires:
  - phase: 02-toolchain-install
    provides: almalinux:8 image with full toolchain (mold/Node/Rust/JDK) + env contract
provides:
  - almalinux-8/fixture/cpp/main.cpp (clang + mold behavioral proof)
  - almalinux-8/fixture/rust/ (std-only Rust crate, no [dependencies])
  - almalinux-8/fixture/gtk_probe.c (display-free GTK header/lib probe)
affects: [03-02]

tech-stack:
  added: []
  patterns: [fixed-string fixture output for diff-ability, std-only crate (no network), display-free GTK accessor probe]

key-files:
  created:
    - almalinux-8/fixture/cpp/main.cpp
    - almalinux-8/fixture/rust/Cargo.toml
    - almalinux-8/fixture/rust/src/main.rs
    - almalinux-8/fixture/gtk_probe.c
    - .planning/phases/03-parity-verification/03-01-SUMMARY.md
  modified: []

key-decisions:
  - "C++ fixture prints fixed string 'cpp-ok 15' via std::accumulate over std::vector; no embedded version, no -fuse-ld=mold (bullseye clang 11 compatibility; mold selected via default-ld shim)"
  - "Rust crate std-only (no [dependencies], edition 2021) so cargo run performs no crates.io fetch; prints 'rust-ok 15'"
  - "GTK probe uses gtk_get_major_version() accessor (display-free, no gtk_init) to prove gtk3-devel headers/libs resolve (PAR-02 / D-07)"

patterns-established:
  - "Fixture sources are deterministic fixed-string programs so both images' stdout can be diff-ed directly (D-06 behavioral equivalence)"
  - "Fixture files carry no compiler/linker flags in-source; the harness compiles with plain clang++/cc and relies on the update-alternatives ld shim"

requirements-completed: [PAR-01, PAR-02]

coverage:
  - id: D1
    description: "C++ fixture proves clang + mold behavioral build (PAR-01)"
    requirement: "PAR-01"
    verification:
      - kind: manual_procedural
        ref: "grep: cpp-ok, accumulate present; fuse-ld absent; file non-empty"
        status: pass
    human_judgment: false
    rationale: "File content gates pass. Runtime proof (clang++ + mold build on both images) is exercised by verify-parity.sh Stage 2 in plan 03-02."
  - id: D2
    description: "Rust fixture proves rustc 1.87.0 behavioral build (PAR-01)"
    requirement: "PAR-01"
    verification:
      - kind: manual_procedural
        ref: "grep: rust-ok in main.rs; edition 2021 in Cargo.toml; no [dependencies]"
        status: pass
    human_judgment: false
    rationale: "File content gates pass. Runtime proof exercised by verify-parity.sh Stage 2."
  - id: D3
    description: "GTK compile probe proves gtk3-devel header/lib resolution (PAR-02)"
    requirement: "PAR-02"
    verification:
      - kind: manual_procedural
        ref: "grep: #include <gtk/gtk.h> and gtk_get_major_version present; gtk_init absent"
        status: pass
    human_judgment: false
    rationale: "File content gates pass. Compile+run proof exercised by verify-parity.sh Stage 2/3."

duration: 10min
completed: 2026-09-09
status: complete
---

# Phase 3 Plan 1: Minimal Build Fixture Summary

## What was built

Four fixture source files under `almalinux-8/fixture/`, the reproducible sample-build inputs the parity harness compiles and runs on both images:

1. `cpp/main.cpp` — C++ program printing the fixed string `cpp-ok 15` (proves clang compiles + mold links via the default-ld shim).
2. `rust/Cargo.toml` + `rust/src/main.rs` — a std-only crate (no `[dependencies]`) printing `rust-ok 15` (proves rustc 1.87.0 builds, no network fetch).
3. `gtk_probe.c` — a display-free GTK probe (`gtk_get_major_version()`) proving EL8 `gtk3-devel` headers/libs resolve (PAR-02).

## Verification

All three task content gates pass:
- C++: contains `cpp-ok` + `accumulate`, no `fuse-ld`, non-empty.
- Rust: `edition = "2021"`, no `[dependencies]`, contains `rust-ok`, non-empty.
- GTK: contains `#include <gtk/gtk.h>` + `gtk_get_major_version`, no `gtk_init`, non-empty.

Runtime compilation/run proof is exercised by `almalinux-8/verify-parity.sh` (plan 03-02).
