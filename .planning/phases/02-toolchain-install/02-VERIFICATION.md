---
phase: 02-toolchain-install
verified: 2026-09-08T12:00:00Z
status: passed
score: 5/5 must-haves verified
overrides_applied: 0
---

# Phase 2: Toolchain Install Verification Report

**Phase Goal:** The image carries the full pinned toolchain and environment contract, completing it as a drop-in replacement for `debian-bullseye`.
**Verified:** 2026-09-08
**Status:** passed
**Re-verification:** No — initial verification (no prior VERIFICATION.md in phase directory)

## Goal Achievement

The phase goal — "the image carries the full pinned toolchain and environment contract, completing it as a drop-in replacement for `debian-bullseye`" — is achieved. Every Roadmap success criterion for Phase 2 is observably true in `almalinux-8/Dockerfile` and independently re-confirmed in the built image `cidocker-almalinux-8:phase2`.

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | `ld --version` reports mold 2.42.0 as the default linker (upstream static tarball + `update-alternatives` shim) | ✓ VERIFIED | Dockerfile mold layer: `moldVersion="2.42.0"`, `update-alternatives --install /usr/bin/ld ld /usr/local/bin/ld.mold 100`, `x86_64`/`aarch64` case map; runtime `docker run --rm cidocker-almalinux-8:phase2 ld --version` → `mold 2.42.0` |
| 2 | `node --version` reports Node 24.x and `node -e 'process.exit(0)'` exits cleanly | ✓ VERIFIED | Dockerfile Node layer: `dnf install -y nodejs && dnf clean all` + `node --version` + `node -e 'process.exit(0)'` probes; runtime `node --version` → `v24.20.0` |
| 3 | `rustc --version` reports Rust 1.87.0 via SHA256-verified rustup; case maps contain only `x86_64`/`aarch64` (no `armhf`/`i386`) | ✓ VERIFIED | Dockerfile Rust layer: both per-arch SHA256 pins (`20a06e64…`, `e3853c5a…`), `sha256sum -c -` check, `rustup-init -y --no-modify-path --profile minimal --default-toolchain 1.87.0`; only `x86_64-unknown-linux-gnu`/`aarch64-unknown-linux-gnu` arms; runtime `rustc --version` → `rustc 1.87.0` |
| 4 | `java -version` reports Temurin JDK 25; `JAVA_HOME`, `JDK_HOME`, `RUSTUP_HOME`, `CARGO_HOME`, and `PATH` match the bullseye env contract | ✓ VERIFIED | Dockerfile JDK layer (`jdk-25.0.2+10`, `temurin-25-jdk` symlink) + final literal `ENV` block (byte-for-byte identical to `debian-bullseye/Dockerfile`); runtime `java -version` → `openjdk 25.0.2 … Temurin-25.0.2+10`, env echo → `JAVA_HOME=/usr/lib/jvm/temurin-25-jdk`, `JDK_HOME=/usr/lib/jvm/temurin-25-jdk`, `RUSTUP_HOME=/usr/local/rustup`, `CARGO_HOME=/usr/local/cargo`, literal `PATH` with no `:$PATH` tail |
| 5 | `git config --system --get safe.directory` returns `*`, and `/var/lib/dbus/machine-id` + `/etc/machine-id` are seeded and identical | ✓ VERIFIED | Dockerfile: `RUN git config --system --add safe.directory '*'` + `cat /proc/sys/kernel/random/uuid | tr -d '-' > /etc/machine-id`; runtime → `*` and `cmp -s /var/lib/dbus/machine-id /etc/machine-id` → `identical` |

**Score:** 5/5 truths verified

### Implementation Deviation (not a failure)

The machine-id glue in `02-03-PLAN.md` Task 2 specified the verbatim bullseye recipe (`cat … > /var/lib/dbus/machine-id && cp /var/lib/dbus/machine-id /etc/machine-id`). On EL8, `/var/lib/dbus/machine-id` is a **symlink to `/etc/machine-id`**, so the `cp` would be a self-copy error. The delivered Dockerfile seeds `/etc/machine-id` directly; the symlink keeps both paths identical automatically. Success criterion 5 (seeded + identical) is fully satisfied. Recorded in `02-03-SUMMARY.md` Deviations. No override required — the truth is VERIFIED, only the mechanism changed.

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `almalinux-8/Dockerfile` | mold 2.42.0 + Node 24 + Rust 1.87.0 + Temurin JDK 25 layers + final ENV + runtime glue + verification chain | ✓ VERIFIED | Full content present and substantive (not a stub). All layers carry real install commands, per-block probes, and the final fail-fast verification chain |
| `almalinux-8/Dockerfile` — final ENV block | `JAVA_HOME`, `JAVA_INCLUDE_PATH{,2}`, `JAVA_AWT_INCLUDE_PATH`, `JAVA_JVM_LIBRARY`, `JDK_HOME`, literal `PATH` | ✓ VERIFIED | Byte-for-byte identical to `debian-bullseye/Dockerfile` final ENV; literal `PATH`, no `:$PATH` append |
| `almalinux-8/Dockerfile` — runtime glue | `git config --system --add safe.directory '*'` + seeded machine-id | ✓ VERIFIED | Both `RUN`s present; machine-id seeded to `/etc/machine-id` (EL8 symlink adaptation) |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|----|--------|---------|
| mold layer | `/usr/local/bin/ld.mold` | `update-alternatives --install /usr/bin/ld ld /usr/local/bin/ld.mold 100` | ✓ WIRED | `ld --version` → `mold 2.42.0` at runtime |
| Node layer | NodeSource 24.x repo (Phase 1 step 5) | `dnf install -y nodejs` | ✓ WIRED | `node --version` → `v24.20.0` at runtime |
| Rust layer | `static.rust-lang.org` rustup 1.28.2 | `wget` + `sha256sum -c` pin check | ✓ WIRED | `rustc --version` → `1.87.0` at runtime |
| JDK layer | `/usr/lib/jvm/temurin-25-jdk` | `ln -sfn` symlink + `profile.d/java-env.sh` | ✓ WIRED | `java -version` → Temurin 25.0.2; `JAVA_HOME` resolves at runtime |
| final ENV | JDK bin (plan 02-02) | literal `PATH` entry `/usr/lib/jvm/temurin-25-jdk/bin:` | ✓ WIRED | Runtime `PATH` starts with JDK bin, then cargo bin |
| verification chain | all five success criteria | fail-fast `grep`/`test`/`cmp` probes | ✓ WIRED | `docker build` exits 0; all nine probes pass |

### Data-Flow Trace (Level 4)

Docker image layers render no UI, so the Level 4 equivalent is: do the installed layers produce **real binaries** (not empty/stubbed files)? Confirmed by in-image runtime probes — every toolchain binary resolves and reports a real version string from the pinned upstream source (mold 2.42.0, Node v24.20.0, rustc 1.87.0, Temurin 25.0.2+10). No hardcoded/empty version placeholders; no `return []`-style stubs.

| Artifact | "Data Variable" | Source | Produces Real Data | Status |
|----------|-----------------|--------|--------------------|--------|
| mold `ld` shim | `ld --version` output | upstream mold 2.42.0 tarball → `/usr/local/bin/ld.mold` | Yes (`mold 2.42.0`) | ✓ FLOWING |
| Node runtime | `node --version` | NodeSource 24.x rpm | Yes (`v24.20.0`) | ✓ FLOWING |
| Rust toolchain | `rustc --version` | rustup 1.28.2 (SHA256-pinned) | Yes (`rustc 1.87.0`) | ✓ FLOWING |
| Temurin JDK | `java -version` | Adoptium `jdk-25.0.2+10` tarball | Yes (`Temurin-25.0.2+10`) | ✓ FLOWING |
| ENV contract | `$JAVA_HOME`/`$PATH`/etc. | final `ENV` block | Yes (literal values) | ✓ FLOWING |
| machine-id | `/var/lib/dbus/machine-id` vs `/etc/machine-id` | `/proc/sys/kernel/random/uuid` seed | Yes (`identical`) | ✓ FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| mold default linker | `docker run --rm cidocker-almalinux-8:phase2 ld --version` | `mold 2.42.0` | ✓ PASS |
| Node runtime | `docker run --rm cidocker-almalinux-8:phase2 node --version` | `v24.20.0` | ✓ PASS |
| Rust compiler | `docker run --rm cidocker-almalinux-8:phase2 rustc --version` | `rustc 1.87.0` | ✓ PASS |
| Temurin JDK | `docker run --rm cidocker-almalinux-8:phase2 java -version` | `openjdk 25.0.2 … Temurin-25.0.2+10` | ✓ PASS |
| git safe.directory | `docker run --rm cidocker-almalinux-8:phase2 git config --system --get safe.directory` | `*` | ✓ PASS |
| machine-id identical | `docker run --rm cidocker-almalinux-8:phase2 sh -c 'cmp -s /var/lib/dbus/machine-id /etc/machine-id && echo identical'` | `identical` | ✓ PASS |
| ENV contract | `docker run --rm cidocker-almalinux-8:phase2 sh -c 'echo $JAVA_HOME $JDK_HOME $RUSTUP_HOME $CARGO_HOME $PATH'` | all literal, PATH has no `:$PATH` tail | ✓ PASS |

Note: `docker build -t cidocker-almalinux-8:phase2 -f almalinux-8/Dockerfile .` → exit 0; the in-image verification chain (last layer) passed all probes. Confirmed by the provided build run and by the fact that the image exists and runs.

### Probe Execution

The phase's authoritative gate is the in-image verification chain (final Dockerfile layer) — it passed during build. No external `scripts/*/tests/probe-*.sh` files exist in this repo (not a migration/tooling phase; verification is baked into the Dockerfile layer).

| Probe | Command | Result | Status |
|-------|---------|--------|--------|
| in-image verification chain | `docker build -t cidocker-almalinux-8:phase2 -f almalinux-8/Dockerfile .` | exit 0; all nine probes green | ✓ PASS |

### Requirements Coverage

Every Phase 2 requirement ID from the plans is accounted for against `REQUIREMENTS.md`:

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| TOOL-01 | 02-01 | mold 2.42.0 from upstream tarball + `update-alternatives` ld shim | ✓ SATISFIED | mold layer + `ld --version` → mold 2.42.0 |
| TOOL-02 | 02-01 | Node 24 installed (NodeSource) | ✓ SATISFIED | Node layer + `node --version` → v24.20.0 |
| TOOL-03 | 02-02 | Rust 1.87.0 via SHA256-pinned rustup, `amd64`+`arm64` only | ✓ SATISFIED | Rust layer (both pins, no 32-bit arms) + `rustc --version` → 1.87.0 |
| TOOL-04 | 02-02 | Temurin JDK 25 via Adoptium tarball, `amd64`+`arm64` only | ✓ SATISFIED | JDK layer (x64/aarch64 arms only) + `java -version` → 25.0.2 Temurin |
| TOOL-05 | 02-03 | Environment contract preserved (`RUSTUP_HOME`, `CARGO_HOME`, `JAVA_HOME`, `PATH`) | ✓ SATISFIED | Final literal ENV block matches bullseye byte-for-byte; runtime env echo confirms |
| PKG-02 | 02-03 | Seeded dbus `machine-id` and `git` safe.directory configured | ✓ SATISFIED | `safe.directory` → `*`; machine-id seeded + identical (EL8 symlink adaptation) |

Orphaned requirement check: `REQUIREMENTS.md` traceability maps exactly PKG-02 + TOOL-01…TOOL-05 to Phase 2. All six appear in the plans' `requirements:` frontmatter (02-01: TOOL-01/02; 02-02: TOOL-03/04; 02-03: TOOL-05/PKG-02). **No orphaned requirements.**

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `almalinux-8/Dockerfile` | 143, 165 | `armhf`/`i386` in comments only ("branches are deleted") | ℹ️ Info | None — explanatory comment, no code arm |

No `TBD`/`FIXME`/`XXX`/`TODO`/`HACK`/`PLACEHOLDER` markers, no empty returns, no hardcoded-empty stubs. No debt markers. No blocker anti-patterns.

### Human Verification Required

None. Every success criterion is programmatically verifiable (version strings, env vars, git config, file identity), and all were confirmed by `docker run` probes. No visual/UX/real-time/external-service judgment is needed for this image phase.

### Gaps Summary

No gaps. All five Roadmap success criteria are VERIFIED in the codebase and independently re-confirmed in the built image. The single implementation deviation (machine-id seeded to `/etc/machine-id` directly due to the EL8 symlink layout) still fully satisfies the criterion and is documented, not a failure.

---

_Verified: 2026-09-08T12:00:00Z_
_Verifier: the agent (gsd-verifier)_
