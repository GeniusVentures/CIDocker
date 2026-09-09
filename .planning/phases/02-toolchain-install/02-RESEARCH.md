# Phase 2: Toolchain Install - Research

**Researched:** 2026-09-08
**Domain:** Upstream-tarball toolchain install (mold / Node / Rust / Temurin JDK) + environment contract + runtime glue — a byte-for-byte parity port of the `debian-bullseye/Dockerfile` toolchain blocks onto AlmaLinux 8 (glibc 2.28).
**Confidence:** HIGH — every URL, archive name, and SHA256 pin was verified live this session against the authoritative upstream hosts (github.com mold/adoptium, static.rust-lang.org), or extracted verbatim from the parity source (`debian-bullseye/Dockerfile`).

## Summary

Phase 2 appends the full pinned toolchain to the Phase-1-complete `almalinux-8/Dockerfile` (which currently ends at step 9, the in-image package verification chain). Four upstream tarballs — mold 2.42.0, Rust 1.87.0 via rustup 1.28.2, Temurin JDK 25.0.2+10, and the NodeSource rpm for Node 24 — plus the final environment contract (`ENV` block) and runtime glue (`git safe.directory`, seeded dbus `machine-id`). Each block is a direct port of the corresponding block in `debian-bullseye/Dockerfile`, with exactly three substitutions: (1) arch detection switches from `dpkg --print-architecture` (`amd64`/`arm64`) to `uname -m` (`x86_64`/`aarch64`), (2) Node install switches from the deb NodeSource script to `dnf install -y nodejs` (repo already enabled in Phase 1), and (3) the `armhf`/`i386` case branches are deleted (BASE-03). Everything else — version pins, `update-alternatives` shim, SHA256-pinned rustup, `--profile minimal`, Adoptium tarball recipe, the literal final `PATH`, and the runtime-glue commands — is carried over **unchanged**.

The critical risk surfaces for Phase 2 are almost all already retired by Phase 1: `wget`/`curl`/`tar`/`ca-certificates` (bootstrap layer), `chkconfig` → `/usr/sbin/update-alternatives` (bootstrap layer), and the NodeSource 24.x rpm repo (step 5) are all in place. The only genuinely new runtime considerations are: (a) `sha256sum` must be present for the rustup pin check (it is — `coreutils`, which provides `sha256sum`, is a hard dependency of the dnf toolchain and present in the minimal image), (b) `uname -m` returns the full string (`x86_64`/`aarch64`) with no `-` suffix, so the analog's `${dpkgArch##*-}` strip pattern must **not** be copied, and (c) `/proc/sys/kernel/random/uuid` and `tr` behave identically on EL8.

**Primary recommendation:** Port each of the four toolchain blocks + final `ENV` + runtime glue verbatim from `debian-bullseye/Dockerfile`, substituting only the `uname -m` case maps, deleting the 32-bit branches, and swapping the Node deb step for `dnf install -y nodejs`; then append one final in-image verification heredoc (mirroring Phase 1 step 9) that asserts all five Phase 2 success criteria (`ld --version`, `node --version` + clean-exit, `rustc --version`, `java -version` + env vars, `git safe.directory` + machine-id identity).

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Node 24 (TOOL-02)**
- **D-01:** Install via the NodeSource rpm repo that Phase 1 already enabled — `dnf install -y nodejs` (rolling 24.x, no exact patch pin). This keeps parity with bullseye (which also leaves 24.x rolling) and satisfies PAR-01's "Node 24" requirement.
- **D-02:** Verify with `node --version` (expect 24.x) and a `node -e 'process.exit(0)'` clean-exit probe in the same layer.

**Rust (TOOL-03)**
- **D-03:** rustup profile stays `--profile minimal` — byte-for-byte parity with bullseye (rustc + cargo + rust-std only; no clippy/rustfmt).
- **D-04:** Keep rustup **1.28.2** with the existing per-arch SHA256 pins (distro-agnostic), keep `--no-modify-path`, `--default-toolchain $RUST_VERSION`, `--default-host ${rustArch}`, and `chmod -R a+w $RUSTUP_HOME $CARGO_HOME`.
- **D-05:** Drop the `armhf`/`i386` case branches — keep only `x86_64-unknown-linux-gnu` and `aarch64-unknown-linux-gnu` (BASE-03).

**Temurin JDK 25 (TOOL-04)**
- **D-06:** Same Adoptium tarball recipe as bullseye (`jdk-25.0.2+10`), `x64`/`aarch64` archives, extract to `/usr/lib/jvm`, `temurin-25-jdk-{amd64|arm64}` dir + `temurin-25-jdk` symlink, `profile.d/java-env.sh` export block.

**Environment Contract (TOOL-05)**
- **D-07:** Byte-for-byte parity with the bullseye final `ENV` block: `PATH` written **literally** (no `:$PATH` append), plus the full `JAVA_HOME`, `JAVA_INCLUDE_PATH`, `JAVA_INCLUDE_PATH2`, `JAVA_AWT_INCLUDE_PATH`, `JAVA_JVM_LIBRARY`, `JDK_HOME` set. The top `ENV` block (`RUSTUP_HOME`/`CARGO_HOME`/`RUST_VERSION`) is already in place from Phase 1 and stays as-is.

**Runtime Glue (PKG-02)**
- **D-08:** `git config --system --add safe.directory '*'` (parity).
- **D-09:** Seed `/var/lib/dbus/machine-id` from `/proc/sys/kernel/random/uuid` (stripped of `-`) and copy it to `/etc/machine-id` — identical to bullseye.

**Architecture Detection (TOOL-03/TOOL-04)**
- **D-10:** Per-block `uname -m` case maps, mirroring the analog's repeated per-block `dpkg --print-architecture` pattern. Each block independently maps `x86_64`/`aarch64` to its own scheme (mold: `x86_64`/`aarch64`; rust: full triples; Temurin: `x64`/`aarch64` + `amd64`/`arm64` dir names), with a hard `exit 1` default for any other arch.

### Claude's Discretion
None — every area was decided explicitly by the user.

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| TOOL-01 | mold 2.42.0 installed from upstream tarball with the `update-alternatives` ld shim (GCC 8.5 cannot pass `-fuse-ld=mold`) | "Toolchain Install Recipe — mold" section: exact URL, archive names, `--strip-components=1` extraction, `update-alternatives --install /usr/bin/ld ld /usr/local/bin/ld.mold 100`, `ld --version` probe. |
| TOOL-02 | Node 24 installed (NodeSource rpm, rolling 24.x) | "Toolchain Install Recipe — Node" section: `dnf install -y nodejs` (repo enabled in Phase 1 step 5), `node --version` + `node -e 'process.exit(0)'` probes; glibc 2.28 floor note. |
| TOOL-03 | Rust 1.87.0 via SHA256-pinned rustup, `amd64`+`arm64` only | "Toolchain Install Recipe — Rust" section: rustup 1.28.2 URL + verified per-arch SHA256, full `rustup-init` command, `uname -m` → triple map, `rustc --version` probe. |
| TOOL-04 | Temurin JDK 25 via Adoptium tarball, `amd64`+`arm64` only | "Toolchain Install Recipe — Temurin JDK" section: `jdk-25.0.2+10` asset names (verified), extract/mv/symlink recipe, `profile.d/java-env.sh`, `java -version` probe. |
| TOOL-05 | Environment contract preserved (`RUSTUP_HOME`, `CARGO_HOME`, `JAVA_HOME`, `PATH`) | "Environment Contract" subsection: the literal final `ENV` block verbatim, plus the already-in-place top `ENV`. |
| PKG-02 | Seeded dbus `machine-id` + `git` safe.directory | "Runtime Glue" subsection: `git config --system --add safe.directory '*'` and the machine-id seed/copy commands, with identity probe. |
</phase_requirements>

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| mold linker install + ld shim | Toolchain layer (single `RUN` heredoc) | — | One upstream-tarball layer; the `update-alternatives` registration mutates `/etc/alternatives` and must be in the same layer as the tarball extraction. |
| Node runtime install | Toolchain layer (single `RUN`) | — | `dnf install nodejs` pulls from the Phase-1-enabled NodeSource repo; cleanup (`dnf clean all`) in the same layer. |
| Rust toolchain install | Toolchain layer (single `RUN` heredoc) | — | `rustup-init` writes into `$RUSTUP_HOME`/`$CARGO_HOME` (top `ENV`); SHA256 check + install + `chmod` must share one layer. |
| Temurin JDK install | Toolchain layer (single `RUN` heredoc) | — | Extract/mv/symlink into `/usr/lib/jvm`; `profile.d/java-env.sh` write must be in the same layer. |
| Environment contract (`JAVA_HOME` etc., literal `PATH`) | Final `ENV` directive (not a `RUN`) | — | `ENV` is image metadata consumed by every later `RUN`/`docker run`; must be the literal bullseye string. |
| Runtime glue (git safe.directory, machine-id) | Runtime-glue layers (two plain `RUN`s) | — | System-level config writes; independent of the toolchain layers, kept as the last two layers for cache stability. |

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| mold | 2.42.0 | Default `ld` (static upstream build) | Distro-agnostic static tarball; EL8 has no mold RPM. Parity with bullseye. |
| Node.js | 24.x (rolling) | JS runtime for CI builds | NodeSource rpm is the only Node 24 source on EL8 (AppStream modules stop at Node 20). |
| rustup | 1.28.2 | Rust toolchain installer | SHA256-pinned installer, distro-agnostic; installs Rust 1.87.0 (`RUST_VERSION`). |
| Rust | 1.87.0 | Compiler + cargo + rust-std (`--profile minimal`) | The pinned toolchain the consuming builds expect. |
| Temurin JDK | 25.0.2+10 | Java runtime for CI builds | Adoptium tarball is distro-agnostic and glibc-2.28-compatible. |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `update-alternatives` | (EL8 `chkconfig` pkg) | Registers mold as default `ld` | Always — GCC 8.5 cannot pass `-fuse-ld=mold` (TOOL-01). |
| `coreutils` (`sha256sum`) | (base) | Verifies rustup-init | Always — the rust block's pin check. |
| `tar` / `wget` / `curl` | (Phase 1 bootstrap) | Download + extract tarballs | Always — already installed in Phase 1. |

**Version verification (performed live this session):**
- mold release `v2.42.0` exists; both asset URLs return HTTP 200: `mold-2.42.0-x86_64-linux.tar.gz`, `mold-2.42.0-aarch64-linux.tar.gz` [VERIFIED: github.com/rui314/mold].
- rustup 1.28.2 archive URLs return HTTP 200; `.sha256` pin files match the bullseye Dockerfile exactly [VERIFIED: static.rust-lang.org].
- Temurin `jdk-25.0.2+10` release assets confirmed: `OpenJDK25U-jdk_x64_linux_hotspot_25.0.2_10.tar.gz` and `OpenJDK25U-jdk_aarch64_linux_hotspot_25.0.2_10.tar.gz` [VERIFIED: github.com/adoptium/temurin25-binaries].

## Package Legitimacy Audit

> This phase installs **zero npm/PyPI/crates packages** — `slopcheck` is not applicable. All external artifacts are upstream tarballs or an official RPM from a first-party vendor repo, secured by TLS + SHA256 pin (rustup) and GPG (NodeSource). Legitimacy is established by provenance, not slopcheck.

| Package / Artifact | Source | Provenance | Integrity | Disposition |
|--------------------|--------|-----------|-----------|-------------|
| mold `mold-2.42.0-{x86_64,aarch64}-linux.tar.gz` | `github.com/rui314/mold/releases/download/v2.42.0/` | mold upstream project (rui314) | GitHub TLS; **no SHA256 pin in the analog** — matches bullseye (flag below) | Approved |
| rustup-init 1.28.2 | `static.rust-lang.org/rustup/archive/1.28.2/{triple}/rustup-init` | Rust project official CDN | **SHA256 pin verified** (bullseye value confirmed live) | Approved |
| Rust 1.87.0 toolchain | via `rustup` | Rust project | rustup verifies manifest + hashes internally | Approved |
| Temurin JDK `OpenJDK25U-jdk_{x64,aarch64}_linux_hotspot_25.0.2_10.tar.gz` | `github.com/adoptium/temurin25-binaries/releases/download/jdk-25.0.2+10/` | Eclipse Adoptium | GitHub TLS; release page publishes SHA256 (available; analog does **not** pin — flag below) | Approved |
| Node.js 24.x | NodeSource rpm repo (enabled Phase 1) | NodeSource (first-party vendor) | GPG via repo file (`gpgcheck=1`) | Approved |

**Packages removed due to slopcheck [SLOP] verdict:** none
**Packages flagged as suspicious [SUS]:** none

**Integrity-pin note (for the planner):** The analog (`debian-bullseye/Dockerfile`) SHA256-pins **only** rustup. mold and Temurin are trusted via GitHub TLS + release provenance. Byte-for-byte parity (D-04/D-06) says keep this exact trust posture. The verified Temurin SHA256 values are recorded in the recipe below should the user ever choose to harden later — but do **not** add them now without a user decision, as that deviates from the analog.

## Toolchain Install Recipe (per tool)

All blocks are appended **after** Phase 1 step 9. Version pins stay shell variables inside each heredoc (not Dockerfile `ARG`s). Multi-command blocks use `RUN <<EOF` + blank line + `set -eux` + blank line + body + blank line + `EOF`.

### 1) mold 2.42.0 (TOOL-01)

```dockerfile
# mold: EL8 has no mold package and GCC 8.5 cannot pass -fuse-ld=mold, so install
# the upstream static build and register it as the default ld. Revert with
# `update-alternatives --set ld /usr/bin/ld.bfd` if a link ever misbehaves.
RUN <<EOF

set -eux

case "$(uname -m)" in \
    x86_64) moldArch='x86_64' ;; \
    aarch64) moldArch='aarch64' ;; \
    *) echo >&2 "unsupported architecture for mold: $(uname -m)"; exit 1 ;; \
esac; \

moldVersion="2.42.0"; \
moldArchive="mold-${moldVersion}-${moldArch}-linux.tar.gz"; \
cd /tmp; \
wget -q "https://github.com/rui314/mold/releases/download/v${moldVersion}/${moldArchive}"; \
tar -xzf "${moldArchive}" -C /usr/local --strip-components=1; \
rm "${moldArchive}"; \
update-alternatives --install /usr/bin/ld ld /usr/local/bin/ld.mold 100; \
ld --version;

EOF
```

**Facts (all verified):**
- Release tag `v2.42.0`; archive names `mold-2.42.0-x86_64-linux.tar.gz` and `mold-2.42.0-aarch64-linux.tar.gz` — both HTTP 200 [VERIFIED: github.com/rui314/mold/releases].
- `uname -m` map: `x86_64` → `x86_64`, `aarch64` → `aarch64` (identical to `uname -m` output; no suffix strip).
- The tarball's top-level directory is stripped (`--strip-components=1`), so `ld.mold` lands at `/usr/local/bin/ld.mold`.
- `update-alternatives --install /usr/bin/ld ld /usr/local/bin/ld.mold 100` — priority 100 outranks the binutils default (`/usr/bin/ld.bfd`, `/usr/bin/ld.gold` both present on EL8).
- `ld --version` prints `mold 2.42.0 ...` — this is the TOOL-01 success probe.

### 2) Node 24 via NodeSource (TOOL-02)

```dockerfile
# Node 24 (rolling, parity with bullseye). The NodeSource rpm repo was enabled in
# Phase 1 step 5; nothing to configure here beyond the install. Node 24 sits exactly
# on the glibc 2.28 floor — the clean-exit probe asserts the binary links and runs.
RUN <<EOF

set -eux

dnf install -y nodejs && dnf clean all
node --version
node -e 'process.exit(0)'

EOF
```

**Facts:**
- `dnf install -y nodejs` resolves from the NodeSource repo enabled in Phase 1 (`curl -fsSL https://rpm.nodesource.com/setup_24.x | bash`). No repo work in Phase 2 [CITED: almalinux-8/Dockerfile step 5 + CONTEXT.md D-01].
- Node 24 requires glibc ≥ 2.28 — AlmaLinux 8's floor is exactly 2.28, so this holds with zero headroom (do **not** downgrade) [CITED: STACK.md].
- Verification probes (D-02): `node --version` (expect `v24.x`) and `node -e 'process.exit(0)'` (clean exit = dynamic linker resolved; TOOL-02 success criterion).
- `dnf clean all` in the same layer (Phase 1 cache-cleanup convention).

### 3) Rust 1.87.0 via rustup 1.28.2 (TOOL-03)

```dockerfile
# Rust via SHA256-pinned rustup (parity with bullseye). amd64 + arm64 only (BASE-03);
# the armhf/i386 branches are deleted. RUST_VERSION/RUSTUP_HOME/CARGO_HOME come from
# the top ENV block.
RUN <<EOF

set -eux

case "$(uname -m)" in \
    x86_64) rustArch='x86_64-unknown-linux-gnu'; rustupSha256='20a06e644b0d9bd2fbdbfd52d42540bdde820ea7df86e92e533c073da0cdd43c' ;; \
    aarch64) rustArch='aarch64-unknown-linux-gnu'; rustupSha256='e3853c5a252fca15252d07cb23a1bdd9377a8c6f3efa01531109281ae47f841c' ;; \
    *) echo >&2 "unsupported architecture: $(uname -m)"; exit 1 ;; \
esac; \

url="https://static.rust-lang.org/rustup/archive/1.28.2/${rustArch}/rustup-init"; \
wget "$url"; \
echo "${rustupSha256} *rustup-init" | sha256sum -c -; \
chmod +x rustup-init; \
./rustup-init -y --no-modify-path --profile minimal --default-toolchain $RUST_VERSION --default-host ${rustArch}; \
rm rustup-init; \
chmod -R a+w $RUSTUP_HOME $CARGO_HOME;

EOF
```

**Facts (all verified live):**
- URL: `https://static.rust-lang.org/rustup/archive/1.28.2/{x86_64-unknown-linux-gnu|aarch64-unknown-linux-gnu}/rustup-init` — HTTP 200 for both [VERIFIED: static.rust-lang.org].
- SHA256 pins — **confirmed byte-for-byte against live `.sha256` files** [VERIFIED]:
  - x86_64: `20a06e644b0d9bd2fbdbfd52d42540bdde820ea7df86e92e533c073da0cdd43c`
  - aarch64: `e3853c5a252fca15252d07cb23a1bdd9377a8c6f3efa01531109281ae47f841c`
- `uname -m` → triple: `x86_64` → `x86_64-unknown-linux-gnu`, `aarch64` → `aarch64-unknown-linux-gnu`.
- `sha256sum` comes from `coreutils`, which is guaranteed present (dnf itself depends on it); the `echo ... | sha256sum -c -` check runs in the cwd where `rustup-init` was downloaded [ASSUMED-HIGH; probe at build time].
- `--profile minimal` installs only rustc + cargo + rust-std (D-03); `--no-modify-path` because the top `ENV` already exports `/usr/local/cargo/bin` (D-04).
- `chmod -R a+w $RUSTUP_HOME $CARGO_HOME` makes toolchain dirs writable for CI.
- Success probe (TOOL-03): `rustc --version` → `rustc 1.87.0 (…)`.

### 4) Temurin JDK 25.0.2+10 (TOOL-04)

```dockerfile
# Temurin JDK 25 via Adoptium tarball (parity). x64/aarch64 only; the armhf/i386
# error branches are deleted. The extracted top-level dir is discovered dynamically
# (it is jdk-25.0.2+10) — do not hardcode it.
RUN <<EOF

set -eux

case "$(uname -m)" in \
    x86_64) jdkArch='x64'; javaDir='amd64' ;; \
    aarch64) jdkArch='aarch64'; javaDir='arm64' ;; \
    *) echo >&2 "unsupported architecture: $(uname -m)"; exit 1 ;; \
esac; \

mkdir -p /usr/lib/jvm; \
cd /tmp; \
jdkReleaseTag="jdk-25.0.2+10"; \
jdkArchive="OpenJDK25U-jdk_${jdkArch}_linux_hotspot_25.0.2_10.tar.gz"; \
wget -q "https://github.com/adoptium/temurin25-binaries/releases/download/${jdkReleaseTag}/${jdkArchive}"; \
extractedDir="$(tar -tzf "${jdkArchive}" | head -1 | cut -d/ -f1)"; \
test -n "${extractedDir}"; \
tar -xzf "${jdkArchive}" -C /usr/lib/jvm; \
mv "/usr/lib/jvm/${extractedDir}" "/usr/lib/jvm/temurin-25-jdk-${javaDir}"; \
ln -sfn /usr/lib/jvm/temurin-25-jdk-${javaDir} /usr/lib/jvm/temurin-25-jdk; \
rm "${jdkArchive}"; \

javaHome="/usr/lib/jvm/temurin-25-jdk"; \
echo "export JAVA_HOME=${javaHome}" >> /etc/profile.d/java-env.sh; \
echo "export JAVA_INCLUDE_PATH=\$JAVA_HOME/include" >> /etc/profile.d/java-env.sh; \
echo "export JAVA_INCLUDE_PATH2=\$JAVA_HOME/include/linux" >> /etc/profile.d/java-env.sh; \
echo "export JAVA_AWT_INCLUDE_PATH=\$JAVA_HOME/include" >> /etc/profile.d/java-env.sh;

EOF
```

**Facts (all verified live):**
- Release tag `jdk-25.0.2+10`; archive names confirmed on the release page [VERIFIED: github.com/adoptium/temurin25-binaries]:
  - `OpenJDK25U-jdk_x64_linux_hotspot_25.0.2_10.tar.gz` (sha256 `987387933b64b9833846dee373b640440d3e1fd48a04804ec01a6dbf718e8ab8`)
  - `OpenJDK25U-jdk_aarch64_linux_hotspot_25.0.2_10.tar.gz` (sha256 `a9d73e711d967dc44896d4f430f73a68fd33590dabc29a7f2fb9f593425b854c`)
- `uname -m` map: `x86_64` → `jdkArch='x64'`, `javaDir='amd64'`; `aarch64` → `jdkArch='aarch64'`, `javaDir='arm64'`.
- The analog discovers the extracted dir dynamically (`tar -tzf | head -1 | cut -d/ -f1`) — keep this; the dir is `jdk-25.0.2+10` but must not be hardcoded.
- The `profile.d/java-env.sh` block writes `JAVA_HOME` as a literal path and the three `JAVA_*_INCLUDE_PATH` vars referencing `$JAVA_HOME` (escaped `\$` so the **literal** `$JAVA_HOME` is written, evaluated at login).
- `JAVA_JVM_LIBRARY` and `JDK_HOME` are **not** in `profile.d` — they live only in the final `ENV` block (below), matching the analog.

### 5) Environment Contract (TOOL-05) — final `ENV` block

```dockerfile
ENV JAVA_HOME=/usr/lib/jvm/temurin-25-jdk \
    JAVA_INCLUDE_PATH=/usr/lib/jvm/temurin-25-jdk/include \
    JAVA_INCLUDE_PATH2=/usr/lib/jvm/temurin-25-jdk/include/linux \
    JAVA_AWT_INCLUDE_PATH=/usr/lib/jvm/temurin-25-jdk/include \
    JAVA_JVM_LIBRARY=/usr/lib/jvm/temurin-25-jdk/lib/server/libjvm.so \
    JDK_HOME=/usr/lib/jvm/temurin-25-jdk \
    PATH=/usr/lib/jvm/temurin-25-jdk/bin:/usr/local/cargo/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
```

**Facts:**
- `PATH` is written **literally** (D-07) — no `:$PATH` append. This is the exact bullseye final `ENV` string.
- `JAVA_JVM_LIBRARY=/usr/lib/jvm/temurin-25-jdk/lib/server/libjvm.so` is correct for **both** x64 and aarch64 (HotSpot ships only the `server` VM in modern JDKs) [VERIFIED: analog writes it literally, arch-independent].
- The **top** `ENV` block (`RUSTUP_HOME`, `CARGO_HOME`, `PATH=…:$PATH`, `RUST_VERSION=1.87.0`) is already in the file from Phase 1 and must stay **unchanged** — its `PATH` **does** append `:$PATH` (that distinction between the two blocks is intentional and matches the analog).

### 6) Runtime Glue (PKG-02)

```dockerfile
RUN git config --system --add safe.directory '*'

RUN mkdir -p /var/lib/dbus && \
    cat /proc/sys/kernel/random/uuid | tr -d '-' > /var/lib/dbus/machine-id && \
    cp /var/lib/dbus/machine-id /etc/machine-id
```

**Facts:**
- `git config --system --add safe.directory '*'` (D-08) — `git` is installed in Phase 1; the command is EL8-identical. Success probe: `git config --system --get safe.directory` returns `*`.
- machine-id seed (D-09) — `cat /proc/sys/kernel/random/uuid | tr -d '-'` works identically on EL8 (kernel procfs; `tr` from `coreutils`). `mkdir -p /var/lib/dbus` is idempotent even though Phase 1 installed `dbus dbus-daemon dbus-tools`.
- **EL8 note:** the `almalinux:8` base may already carry an (empty or placeholder) `/etc/machine-id`. The `cp` overwrites it, guaranteeing `/var/lib/dbus/machine-id` and `/etc/machine-id` are identical — the PKG-02 success criterion. No EL8 behavioral difference from bullseye.
- Success probe: `cmp -s /var/lib/dbus/machine-id /etc/machine-id && test -s /var/lib/dbus/machine-id`.

## Final Verification Chain (recommended — mirrors Phase 1 step 9)

Append one heredoc after runtime glue asserting **all five** Phase 2 success criteria in a single fail-fast layer:

```dockerfile
# 10) Phase 2 verification chain — fails the build if any success criterion is unmet.
RUN <<EOF

set -eux

ld --version | grep -q 'mold 2.42.0'
node --version | grep -q '^v24\.'
node -e 'process.exit(0)'
rustc --version | grep -q '1.87.0'
java -version 2>&1 | grep -q 'Temurin-25'
test "$(git config --system --get safe.directory)" = '*'
test -s /var/lib/dbus/machine-id
cmp -s /var/lib/dbus/machine-id /etc/machine-id
echo "JAVA_HOME=$JAVA_HOME JDK_HOME=$JDK_HOME RUSTUP_HOME=$RUSTUP_HOME CARGO_HOME=$CARGO_HOME"

EOF
```

The per-block probes (`ld --version` in mold; `node --version` + clean-exit in Node) stay for parity; this final chain is the authoritative phase gate and covers the env-contract assertions.

## Architecture Patterns

### Recommended Project Structure

```
W:\gnus\CIDocker\
├── README.md
├── .planning\                          # GSD artifacts (not part of image builds)
├── debian-bullseye\
│   └── Dockerfile                      # parity source of truth (unchanged)
└── almalinux-8\
    └── Dockerfile                      # target — Phase 2 appends after step 9
```

### Pattern 1: One upstream tarball per layer, version pinned as a shell var
**What:** Each toolchain component (mold, rust, Temurin) gets its own `RUN <<EOF` + `set -eux` heredoc with the version/URL/hash as in-block shell variables (e.g. `moldVersion="2.42.0"`), never Dockerfile `ARG`s.
**Why:** Mirrors the analog exactly; keeps each tarball's download/extract/cleanup/verify atomic; layer-cache isolates toolchain versions from each other.

### Pattern 2: `uname -m` per-block case maps with hard `exit 1` default
**What:** Each block independently runs `case "$(uname -m)" in x86_64)… aarch64)… *) exit 1 ;; esac`.
**Why:** Self-contained blocks (D-10), works under buildx qemu emulation for Phase 4, and enforces BASE-03 (no 32-bit arches). Match on the **full** `uname -m` string — do **not** copy the analog's `${dpkgArch##*-}` suffix-strip pattern (there is no `-` in `x86_64`/`aarch64`).

### Pattern 3: `wget -q` → verify → extract → cleanup → probe
**What:** `wget -q` the asset → (rust only) SHA256 check → `tar -xzf` → `rm` archive → `--version` probe in the same layer.
**Why:** Established Phase-1/analog convention; leaves no archives in the image and fails fast on a bad download.

### Anti-Patterns to Avoid
- **Copying `dpkg --print-architecture` / `${dpkgArch##*-}`** — EL8 has no dpkg; use `uname -m` and match the full string.
- **Keeping `armhf`/`i386` branches** — RHEL clones ship neither; the analog's rust block has them and they must be **deleted** (D-05).
- **Hardcoding the Temurin extracted dir** — discover it via `tar -tzf | head -1 | cut -d/ -f1` (the analog's approach); hardcoding breaks if Adoptium changes the top-level dir name.
- **Adding `:$PATH` to the final `ENV`** — the final block writes `PATH` literally (D-07); only the top block appends.
- **Pinning mold/Temurin SHA256 "for safety"** — deviates from the analog's trust posture (D-04/D-06 parity); if hardening is wanted, that's a user decision, not a silent addition.
- **Splitting the tarball `rm` or `dnf clean all` into a later layer** — cleanup must be in the same `RUN` that created the artifacts.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| mold on EL8 | Build mold from source or search for an RPM | Upstream static tarball + `update-alternatives` shim | No mold RPM exists on EL8; the static build is the analog's proven recipe. |
| Default linker override | Patch build scripts to pass `-fuse-ld=mold` | `update-alternatives --install /usr/bin/ld ld /usr/local/bin/ld.mold 100` | GCC 8.5 can't pass `-fuse-ld=mold`; the shim is the only path (and matches bullseye link commands byte-for-byte). |
| Rust install | Distro rustc (EL8 has none modern) | SHA256-pinned `rustup-init` | rustup 1.28.2 + Rust 1.87.0 is distro-agnostic and the pinned parity version. |
| Node 24 on EL8 | `dnf module enable nodejs` (max Node 20) | NodeSource rpm | Node 24 requires glibc ≥ 2.28; only NodeSource ships 24.x for EL8. |
| JDK install | Distro OpenJDK (EL8 ships 17) | Adoptium `jdk-25.0.2+10` tarball | Temurin 25 is the pinned parity version; Adoptium builds target old glibc. |
| machine-id | Custom UUID generation scripts | `cat /proc/sys/kernel/random/uuid | tr -d '-'` | Kernel-provided, identical to the analog. |

**Key insight:** every one of these is an upstream-artifact reality, not a custom-code opportunity. The analog's blocks are already the expert-correct recipes; the port is a mechanical substitution (arch detection + Node repo), not a redesign.

## Common Pitfalls

### Pitfall 1: `uname -m` returns the full string — don't strip a `-` suffix
**What goes wrong:** Copying the analog's `case "${dpkgArch##*-}"` with `uname -m` yields `x86_64`/`aarch64` unchanged (no harm) but is misleading, and a future editor may expect `amd64`/`arm64` tokens.
**Why:** `uname -m` already returns the exact canonical token; there is no dash-separated prefix.
**How to avoid:** Match `case "$(uname -m)" in x86_64) … aarch64) … *) exit 1 ;; esac` directly.
**Warning signs:** A case arm that never matches, or a `##*-` strip in the EL8 file.

### Pitfall 2: Node 24 sits exactly on the glibc 2.28 floor
**What goes wrong:** A `node --version` that prints fine but any `node` execution segfaults if the binary was actually built for a newer glibc.
**Why:** Node 24's minimum glibc is 2.28 — AlmaLinux 8's exact floor; zero headroom.
**How to avoid:** Install only from NodeSource (built for RHEL 8); assert `node -e 'process.exit(0)'` (the clean-exit probe) in the same layer as the install.
**Warning signs:** `node: /lib64/libc.so.6: version 'GLIBC_2.33' not found` — means a non-EL8 binary got in.

### Pitfall 3: `update-alternatives` present only because `chkconfig` was installed
**What goes wrong:** `update-alternatives: command not found` if the mold block runs in an image without Phase 1's bootstrap.
**Why:** On EL8 `update-alternatives` lives in the `chkconfig` package (not in the minimal base).
**How to avoid:** It is already installed in Phase 1 step 1 (`chkconfig`). Do not re-install; do not assume it's in every minimal EL8 image.
**Warning signs:** Build failure at the mold block's `update-alternatives --install` line.

### Pitfall 4: `sha256sum` requires `coreutils` (present, but be aware)
**What goes wrong:** The rust block's `sha256sum -c` fails if someone later swaps to a stripped base image.
**Why:** `sha256sum` is a `coreutils` binary; `coreutils` is a hard dependency of dnf and present in `almalinux:8`, so this is fine today but is an implicit dependency.
**How to avoid:** Keep the `wget`-then-`echo … | sha256sum -c -` order; run the check in the same cwd where `rustup-init` was downloaded (`wget "$url"` writes `./rustup-init`).
**Warning signs:** `sha256sum: rustup-init: No such file or directory` — means the cwd is wrong or the file was renamed.

### Pitfall 5: `tar --strip-components=1` for mold must point at `/usr/local`
**What goes wrong:** Extracting without `--strip-components=1` nests everything under `/usr/local/mold-2.42.0-x86_64-linux/`, so `/usr/local/bin/ld.mold` never exists and the `update-alternatives --install` points at a missing path.
**Why:** The mold tarball has a versioned top-level directory.
**How to avoid:** `tar -xzf "${moldArchive}" -C /usr/local --strip-components=1` exactly as in the analog.
**Warning signs:** `ld --version` still reports GNU ld after install, or `update-alternatives --install` complains the target is absent.

### Pitfall 6: Git `safe.directory` is additive and must use `--add`
**What goes wrong:** Using `git config --system safe.directory '*'` (without `--add`) overwrites rather than appends, or re-running the build with `--add` accumulates duplicate entries.
**Why:** `--add` appends a new value; the analog uses `--add`.
**How to avoid:** Keep `git config --system --add safe.directory '*'` verbatim. (A rebuild from a clean layer never accumulates, so duplicates are a non-issue inside Docker.)
**Warning signs:** `git config --system --get safe.directory` returning empty or a path instead of `*`.

### Pitfall 7: `/etc/machine-id` pre-existing in the base image
**What goes wrong:** Assuming the base image has no `/etc/machine-id` and skipping the `cp`, leaving `/etc/machine-id` and `/var/lib/dbus/machine-id` different.
**Why:** `almalinux:8` may ship an empty or placeholder `/etc/machine-id`; dbus/systemd expect a valid 32-hex-char id.
**How to avoid:** Always run the `cat … > /var/lib/dbus/machine-id` + `cp … /etc/machine-id` sequence; verify with `cmp -s`.
**Warning signs:** `cmp` returning non-zero, or a 0-byte machine-id.

## Code Examples

Verified patterns from the authoritative sources (parity source + live verification):

### mold block (port of `debian-bullseye/Dockerfile` lines 37-58)
See "Toolchain Install Recipe — mold" above.

### rust block (port of lines 59-85, with 32-bit branches deleted)
See "Toolchain Install Recipe — Rust" above.

### Temurin block + final ENV (port of lines 86-125)
See "Toolchain Install Recipe — Temurin JDK" + "Environment Contract" above.

### Runtime glue (port of lines 130-134)
See "Toolchain Install Recipe — Runtime Glue" above.

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `dpkg --print-architecture` arch detection (`amd64`/`arm64` + `${##*-}` strip) | `uname -m` (`x86_64`/`aarch64`, full-string match) | This port | EL8 has no dpkg; the map keys change but the resulting per-tool schemes (mold arch, rust triples, Temurin `x64`/`aarch64`) are identical. |
| Node via `deb.nodesource.com/setup_24.x \| sudo -E bash -` | NodeSource rpm repo enabled in Phase 1 + `dnf install -y nodejs` | This port | Repo enablement moved to Phase 1; Phase 2 is a plain dnf install with `dnf clean all`. |
| rust `armhf`/`i386` branches | deleted | This port | RHEL clones ship neither 32-bit target (BASE-03); hard `exit 1` default remains. |
| mold shim motivated by clang 11 lacking `-fuse-ld=mold` | kept for byte-for-byte link parity even though EL8 clang 17 supports `-fuse-ld=mold` natively | This port | Shim is now optional-but-harmless; retained for identical link commands. |

**Deprecated/outdated:**
- `Acquire::Check-Valid-Until=false` / backports workarounds — already deleted in Phase 1, not present here.
- Any idea of a mold RPM on EL8 — none exists; upstream tarball is the only path (unchanged).

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `sha256sum` (coreutils) is present in the minimal `almalinux:8` base — it is a hard dnf dependency but not explicitly installed in Phase 1 | Rust recipe | If absent, `sha256sum -c` fails; trivially fixed by adding `coreutils` to the bootstrap (probe at build time). Low impact. |
| A2 | `JAVA_JVM_LIBRARY=…/lib/server/libjvm.so` is correct for the aarch64 build (HotSpot server VM only) | Environment Contract | If aarch64 Temurin used a different `libjvm.so` path, `JAVA_JVM_LIBRARY` would be wrong on arm64 — but the analog writes it arch-independently and it is verified in Phase 4. Low impact, Phase 4 re-verifies. |
| A3 | NodeSource `dnf install nodejs` will resolve to a 24.x package on EL8 (repo enabled in Phase 1) | Node recipe | If NodeSource's EL8 repo names the package differently (it does not — `nodejs` is the standard name), the install fails. Low impact; surfaced at build time. |

**Notes on claims otherwise:** every URL, archive name, and hash in the recipes is `[VERIFIED]` live this session or `[CITED]` from the parity source — not assumed.

## Open Questions (RESOLVED)

1. **Should mold and Temurin tarballs gain SHA256 pinning?**
   - RESOLVED: keep parity (no extra pins) for Phase 2 — the analog pins only rustup; mold/Temurin are trusted via GitHub TLS. Live-verified Temurin SHA256 values are recorded above. Raise hardening as an explicit user decision if desired later.
   - What we know: the analog pins only rustup; mold/Temurin are trusted via GitHub TLS. Live-verified Temurin SHA256 values are recorded above; mold asset hashes are retrievable from the release page.
   - Recommendation: keep parity (no extra pins) for Phase 2; raise as an explicit user decision if hardening is desired later.

2. **Single final verification chain vs. per-block probes only?**
   - RESOLVED: keep the per-block probes (parity) **and** append the consolidated chain (Section "Final Verification Chain") — it directly encodes the five success criteria and mirrors Phase 1's step-9 pattern.
   - What we know: D-02 mandates the Node probe in-layer; the analog embeds only `ld --version`.
   - Recommendation: keep the per-block probes (parity) **and** append the consolidated chain (Section "Final Verification Chain") — it directly encodes the five success criteria and mirrors Phase 1's step-9 pattern.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| `wget`, `curl`, `tar`, `gzip`, `ca-certificates` | tarball downloads/extraction | ✓ (Phase 1 bootstrap) | — | — |
| `chkconfig` → `update-alternatives` | mold ld shim | ✓ (Phase 1 bootstrap) | — | — |
| `sha256sum` (`coreutils`) | rustup pin check | ⚠️ assumed present (not explicitly installed) | — | add `coreutils` to bootstrap if probe fails |
| NodeSource rpm repo | `dnf install nodejs` | ✓ (Phase 1 step 5) | 24.x | — |
| Docker daemon (Docker Desktop engine) | `docker build` + success-criteria verification | ✗ **not running** | — | Start Docker Desktop before executing/verifying Phase 2 |
| Network → github.com (mold, adoptium), static.rust-lang.org | tarball + rustup downloads | ⚠️ not probed | — | Required at build time; standard public egress assumed |

**Missing dependencies with no fallback:**
- Docker daemon must be running to satisfy Phase 2 success criteria (build + `ld`/`node`/`rustc`/`java` probes). Start Docker Desktop prior to execution.

**Missing dependencies with fallback:**
- `sha256sum`/`coreutils` — if the minimal image somehow lacks it, add `coreutils` to the Phase 1 bootstrap layer (one-line fix).

## Security Domain

> `security_enforcement: true` (ASVS level 1). This phase is a **CI build image**, not a web application; the applicable surface is **software supply chain**.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | N/A — no app-level auth |
| V3 Session Management | no | N/A |
| V4 Access Control | no | N/A |
| V5 Input Validation | no | N/A — no user input surface |
| V6 Cryptography | partial | SHA256 pin (rustup) + GitHub/static.rust-lang.org TLS + GPG (NodeSource); never hand-roll crypto. |

### Known Threat Patterns for a tarball-based CI image

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Tampered rustup binary | Tampering | SHA256 pin verified with `sha256sum -c -` before execution. |
| Tampered mold/Temurin tarball | Tampering | GitHub release provenance over TLS; (optional hardening: pin hashes — deferred, see Open Questions). |
| Floating/rolling toolchain versions | Tampering | Pinned mold 2.42.0, rustup 1.28.2, Rust 1.87.0, Temurin 25.0.2+10; Node intentionally rolling (D-01, parity). |
| Unauthenticated script execution | Spoofing/Tampering | None in Phase 2 (NodeSource script already run + deleted in Phase 1); tarballs are direct TLS downloads. |
| Excessive attack surface | Elevation of privilege | `--profile minimal` Rust (no clippy/rustfmt); no docs, no extra JDK debug/test images; archives deleted after extraction. |
| World-writable toolchain dirs | Tampering | `chmod -R a+w $RUSTUP_HOME $CARGO_HOME` is intentional for CI (mirrors the analog); scoped to those two dirs only. |

## Sources

### Primary (HIGH confidence — verified live this session)
- `github.com/rui314/mold/releases/tag/v2.42.0` — release exists; both `mold-2.42.0-{x86_64,aarch64}-linux.tar.gz` assets HTTP 200.
- `static.rust-lang.org/rustup/archive/1.28.2/{x86_64-unknown-linux-gnu,aarch64-unknown-linux-gnu}/rustup-init` — HTTP 200; `.sha256` files match the bullseye pins.
- `github.com/adoptium/temurin25-binaries/releases/tag/jdk-25.0.2+10` — asset names + SHA256 for `OpenJDK25U-jdk_{x64,aarch64}_linux_hotspot_25.0.2_10.tar.gz`.
- `W:\gnus\CIDocker\debian-bullseye\Dockerfile` — authoritative parity source of truth (all four toolchain blocks, final ENV, runtime glue).
- `W:\gnus\CIDocker\almalinux-8\Dockerfile` — current target state (Phase 1 complete through step 9).

### Secondary (MEDIUM confidence — prior-session research, cross-referenced)
- `.planning/research/STACK.md` — carry-over assessment (mold 2.42.0, rustup 1.28.2 → Rust 1.87.0, Temurin 25.0.2+10, Node 24 rpm); glibc-2.28 floors; "What NOT to Use".
- `.planning/phases/01-base-package-install/01-PATTERNS.md` — heredoc + `set -eux`, shell-var pins, comment convention, runtime-glue block, arch-detection note.
- `.planning/phases/01-base-package-install/01-RESEARCH.md` — cache-cleanup strategy, "no arch branching in Phase 1" note.

### Tertiary (LOW confidence — flagged for build-time validation)
- `sha256sum`/`coreutils` presence in the minimal base (A1) — probe at build time.

## Metadata

**Confidence breakdown:**
- Standard stack / toolchain recipe: HIGH — URLs, archive names, and SHA256 pins verified live against authoritative upstream hosts or extracted from the parity source.
- Architecture (block structure, layer ordering): HIGH — direct port of the analog with mechanical substitutions.
- Pitfalls: HIGH-MEDIUM — grounded in the analog and EL8 packaging facts; the coreutils and aarch64 `libjvm.so` items flagged for build-time confirmation.

**Research date:** 2026-09-08
**Valid until:** 2026-10-08 (stable toolchain pins — Rust 1.87.0, mold 2.42.0, Temurin 25.0.2+10 are immutable; Node 24.x is rolling and may advance patch versions within the month).
