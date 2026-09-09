# Phase 2: Toolchain Install - Context

**Gathered:** 2026-09-08
**Status:** Ready for planning

## Phase Boundary

The `almalinux-8/Dockerfile` gains the full pinned toolchain and environment contract, completing it as a drop-in replacement for `debian-bullseye`. This phase appends layers after Phase 1's package-install + verification blocks for: mold 2.42.0 (upstream static tarball + `update-alternatives` ld shim), Node 24 (NodeSource rpm), Rust 1.87.0 (SHA256-verified rustup, `amd64`/`arm64` only), Temurin JDK 25 (Adoptium tarball), the full `JAVA_HOME`/`PATH` env contract, and runtime glue (`git safe.directory`, seeded dbus `machine-id`). Requirements: TOOL-01, TOOL-02, TOOL-03, TOOL-04, TOOL-05, PKG-02.

## Implementation Decisions

### Node 24 (TOOL-02)
- **D-01:** Install via the NodeSource rpm repo that Phase 1 already enabled — `dnf install -y nodejs` (rolling 24.x, no exact patch pin). This keeps parity with bullseye (which also leaves 24.x rolling) and satisfies PAR-01's "Node 24" requirement.
- **D-02:** Verify with `node --version` (expect 24.x) and a `node -e 'process.exit(0)'` clean-exit probe in the same layer.

### Rust (TOOL-03)
- **D-03:** rustup profile stays `--profile minimal` — byte-for-byte parity with bullseye (rustc + cargo + rust-std only; no clippy/rustfmt).
- **D-04:** Keep rustup **1.28.2** with the existing per-arch SHA256 pins (distro-agnostic), keep `--no-modify-path`, `--default-toolchain $RUST_VERSION`, `--default-host ${rustArch}`, and `chmod -R a+w $RUSTUP_HOME $CARGO_HOME`.
- **D-05:** Drop the `armhf`/`i386` case branches — keep only `x86_64-unknown-linux-gnu` and `aarch64-unknown-linux-gnu` (BASE-03).

### Temurin JDK 25 (TOOL-04)
- **D-06:** Same Adoptium tarball recipe as bullseye (`jdk-25.0.2+10`), `x64`/`aarch64` archives, extract to `/usr/lib/jvm`, `temurin-25-jdk-{amd64|arm64}` dir + `temurin-25-jdk` symlink, `profile.d/java-env.sh` export block.

### Environment Contract (TOOL-05)
- **D-07:** Byte-for-byte parity with the bullseye final `ENV` block: `PATH` written **literally** (no `:$PATH` append), plus the full `JAVA_HOME`, `JAVA_INCLUDE_PATH`, `JAVA_INCLUDE_PATH2`, `JAVA_AWT_INCLUDE_PATH`, `JAVA_JVM_LIBRARY`, `JDK_HOME` set. The top `ENV` block (`RUSTUP_HOME`/`CARGO_HOME`/`RUST_VERSION`) is already in place from Phase 1 and stays as-is.

### Runtime Glue (PKG-02)
- **D-08:** `git config --system --add safe.directory '*'` (parity).
- **D-09:** Seed `/var/lib/dbus/machine-id` from `/proc/sys/kernel/random/uuid` (stripped of `-`) and copy it to `/etc/machine-id` — identical to bullseye.

### Architecture Detection (TOOL-03/TOOL-04)
- **D-10:** Per-block `uname -m` case maps, mirroring the analog's repeated per-block `dpkg --print-architecture` pattern. Each block independently maps `x86_64`/`aarch64` to its own scheme (mold: `x86_64`/`aarch64`; rust: full triples; Temurin: `x64`/`aarch64` + `amd64`/`arm64` dir names), with a hard `exit 1` default for any other arch.

### Claude's Discretion
None — every area was decided explicitly by the user.

## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Parity source of truth
- `debian-bullseye/Dockerfile` — the authoritative analog: mold block (lines ~37-58), rust block (~59-85), JDK block (~86-125), final ENV block, and runtime glue (~130-134). Port each block to EL8; do not reinvent.

### Target file (Phase 1 complete)
- `almalinux-8/Dockerfile` — current state through step 9 (verification chain). Phase 2 layers are appended **after** step 9; do not disturb the repo/install layers.

### Conventions & research
- `.planning/phases/01-base-package-install/01-PATTERNS.md` — heredoc `RUN <<EOF` + `set -eux`, version pins as shell vars (not `ARG`s), comment convention (why + revert command), runtime-glue block, arch-detection note ("`uname -m` — Phase 2").
- `.planning/phases/01-base-package-install/01-RESEARCH.md` — ordered dnf recipe, cache-cleanup strategy (clean in the same layer; keep `/var/lib/dnf`), "Pattern 3: No arch branching in Phase 1 — arch detection is Phase 2".
- `.planning/research/STACK.md` — Toolchain carry-over assessment (mold 2.42.0, rustup 1.28.2 → Rust 1.87.0, Temurin 25.0.2+10, Node 24 via rpm.nodesource.com); "What NOT to Use" (armhf/i386, crb on 8).

### Requirements & roadmap
- `.planning/REQUIREMENTS.md` — TOOL-01…TOOL-05, PKG-02 definitions.
- `.planning/ROADMAP.md` — Phase 2 success criteria (5 items) and "Phase 2: Toolchain Install" details.

## Existing Code Insights

### Reusable Assets
- `debian-bullseye/Dockerfile` toolchain blocks — the exact analog for mold/Rust/JDK/Node/runtime-glue. Port each verbatim with only the EL8 substitutions (arch detection, NodeSource rpm vs deb, drop armhf/i386).

### Established Patterns
- Heredoc `RUN <<EOF` + blank line + `set -eux` for multi-command blocks; plain single-line `RUN` for one-offs.
- Version pins as in-block shell variables (e.g. `moldVersion="2.42.0"`), not Dockerfile `ARG`s.
- `wget -q` → `tar -xzf` → `rm archive` → verify (`--version` probe) per upstream tarball.
- Two `ENV` blocks: top (appends `:$PATH`) and final JDK (literal `PATH`) — keep both distinct.

### Integration Points
- Append after step 9's verification heredoc in `almalinux-8/Dockerfile`.
- Top `ENV` already exports `RUSTUP_HOME`, `CARGO_HOME`, `RUST_VERSION=1.87.0` — consumed by the rust block.
- NodeSource 24.x repo and `chkconfig` (`update-alternatives`) are already present from Phase 1 — no repo or bootstrap work needed in Phase 2.
- `wget`/`curl`/`tar`/`ca-certificates` are installed in Phase 1's bootstrap layer — available for the tarball installs.

## Specific Ideas

No specific references beyond byte-for-byte parity with `debian-bullseye/Dockerfile`. Open to standard approaches for anything not explicitly decided above.

## Deferred Ideas

None — discussion stayed within phase scope.

---

*Phase: 2-Toolchain Install*
*Context gathered: 2026-09-08*
