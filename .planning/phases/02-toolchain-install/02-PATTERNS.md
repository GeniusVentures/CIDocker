# Phase 2: Toolchain Install - Pattern Map

**Mapped:** 2026-09-08
**Files analyzed:** 1 (modified)
**Analogs found:** 1 / 1

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `almalinux-8/Dockerfile` | Dockerfile / CI build-image definition | build-time layer stack (batch image assembly) | `debian-bullseye/Dockerfile` | exact |

> Single-file phase. `almalinux-8/Dockerfile` is **modified** — Phase 2 appends the
> toolchain + env + runtime-glue layers **after** Phase 1 step 9 (the in-image
> verification heredoc). The analog is the same parity source of truth as Phase 1:
> `debian-bullseye/Dockerfile`. Every toolchain block is a verbatim port with exactly
> three substitutions (arch detection, Node install path, dropped 32-bit branches).

---

## Pattern Assignments

The target file already has these layers (Phase 1, do **not** disturb):
frontmatter + `FROM almalinux:8` (lines 1-2), top `ENV` block (lines 4-7), steps 1-9
(repo enablement → package install → verification chain, lines 9-77). Phase 2 appends
six blocks below step 9.

### 1. mold 2.42.0 + `update-alternatives` ld shim (TOOL-01)

**Analog** (`debian-bullseye/Dockerfile`, lines 42-59):

```dockerfile
# mold: bullseye has no mold package, and clang 11 predates -fuse-ld=mold, so install the
# upstream static build and register it as the default ld. Revert with
# `update-alternatives --set ld /usr/bin/ld.bfd` if a link ever misbehaves.
dpkgArch="$(dpkg --print-architecture)"; \
case "${dpkgArch##*-}" in \
    amd64) moldArch='x86_64' ;; \
    arm64) moldArch='aarch64' ;; \
    *) echo >&2 "unsupported architecture for mold: ${dpkgArch}"; exit 1 ;; \
esac; \

moldVersion="2.42.0"; \
moldArchive="mold-${moldVersion}-${moldArch}-linux.tar.gz"; \
cd /tmp; \
wget -q "https://github.com/rui314/mold/releases/download/v${moldVersion}/${moldArchive}"; \
tar -xzf "${moldArchive}" -C /usr/local --strip-components=1; \
rm "${moldArchive}"; \
update-alternatives --install /usr/bin/ld ld /usr/local/bin/ld.mold 100; \
ld --version;
```

**Target — EL8 form** (from `02-RESEARCH.md`; heredoc + `set -eux`, `uname -m`):

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

**Substitutions:**
- `dpkgArch="$(dpkg --print-architecture)"` + `${dpkgArch##*-}` strip → `case "$(uname -m)"` with full-string match (`x86_64`/`aarch64`). No `-` suffix to strip.
- `amd64) moldArch='x86_64'` → `x86_64) moldArch='x86_64'`; `arm64) moldArch='aarch64'` → `aarch64) moldArch='aarch64'`.
- Everything else (URL, `--strip-components=1`, `update-alternatives` priority 100, `ld --version` probe) is **unchanged**.

**Facts to honor:**
- `update-alternatives` exists because Phase 1 step 1 installed `chkconfig` — do not re-install it.
- `tar --strip-components=1` must point at `/usr/local` so `ld.mold` lands at `/usr/local/bin/ld.mold`.
- `ld --version` is the per-block TOOL-01 probe; expect `mold 2.42.0`.

---

### 2. Node 24 (TOOL-02)

**Analog** (`debian-bullseye/Dockerfile`, lines 61-62) — inside the mold heredoc:

```dockerfile
curl -fsSL https://deb.nodesource.com/setup_24.x | sudo -E bash -
sudo apt install -y nodejs
```

**Target — EL8 form** (own heredoc; NodeSource repo already enabled in Phase 1 step 5):

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

**Substitutions:**
- Drop the `curl ... | sudo -E bash -` + `sudo apt install nodejs` pair — the rpm repo is already in place; the only remaining step is `dnf install -y nodejs`.
- `node --version` (expect `v24.x`) + `node -e 'process.exit(0)'` clean-exit probe (D-02). The clean-exit probe is **new** relative to the analog but is the CONTEXT.md-mandated TOOL-02 verification.

**Facts to honor:**
- Node 24 requires glibc ≥ 2.28 — exactly AlmaLinux 8's floor (zero headroom). Never downgrade.
- `dnf clean all` in the same layer (Phase 1 cache-cleanup convention).

---

### 3. Rust 1.87.0 via rustup 1.28.2 (TOOL-03)

**Analog** (`debian-bullseye/Dockerfile`, lines 66-87):

```dockerfile
RUN <<EOF

set -eux

dpkgArch="$(dpkg --print-architecture)"; \
case "${dpkgArch##*-}" in \
    amd64) rustArch='x86_64-unknown-linux-gnu'; rustupSha256='20a06e644b0d9bd2fbdbfd52d42540bdde820ea7df86e92e533c073da0cdd43c' ;; \
    armhf) rustArch='armv7-unknown-linux-gnueabihf'; rustupSha256='3b8daab6cc3135f2cd4b12919559e6adaee73a2fbefb830fadf0405c20231d61' ;; \
    arm64) rustArch='aarch64-unknown-linux-gnu'; rustupSha256='e3853c5a252fca15252d07cb23a1bdd9377a8c6f3efa01531109281ae47f841c' ;; \
    i386) rustArch='i686-unknown-linux-gnu'; rustupSha256='a5db2c4b29d23e9b318b955dd0337d6b52e93933608469085c924e0d05b1df1f' ;; \
    *) echo >&2 "unsupported architecture: ${dpkgArch}"; exit 1 ;; \
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

**Target — EL8 form** (drop `armhf`/`i386`; `uname -m` → triple map):

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

**Substitutions:**
- Delete the `armhf)` and `i386)` case arms (BASE-03).
- `amd64)` arm key → `x86_64)`; `arm64)` arm key → `aarch64)`. Triple values unchanged.

**Facts to honor (all live-verified in RESEARCH.md):**
- SHA256 pins carried verbatim — `20a06e644b...` (x86_64), `e3853c5a25...` (aarch64). This is the **only** SHA256-pinned artifact (matches the analog's trust posture).
- `--profile minimal`, `--no-modify-path`, `--default-toolchain $RUST_VERSION`, `--default-host ${rustArch}`, `chmod -R a+w $RUSTUP_HOME $CARGO_HOME` all unchanged.
- `sha256sum` comes from `coreutils` (guaranteed present). Run the check in the same cwd where `wget "$url"` wrote `./rustup-init`.

---

### 4. Temurin JDK 25.0.2+10 (TOOL-04)

**Analog** (`debian-bullseye/Dockerfile`, lines 89-120):

```dockerfile
RUN <<EOF

set -eux

dpkgArch="$(dpkg --print-architecture)"; \
case "${dpkgArch##*-}" in \
    amd64) jdkArch='x64'; javaDir='amd64' ;; \
    armhf) echo >&2 "armhf is not supported by Temurin JDK 25 Linux binaries"; exit 1 ;; \
    arm64) jdkArch='aarch64'; javaDir='arm64' ;; \
    i386) echo >&2 "i386 not supported by Temurin"; exit 1 ;; \
    *) echo >&2 "unsupported architecture: ${dpkgArch}"; exit 1 ;; \
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

**Target — EL8 form** (drop the two error arms; `uname -m` → `x64`/`aarch64` + `amd64`/`arm64` dirs):

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

**Substitutions:**
- Delete the `armhf)` and `i386)` error arms — they become unreachable under the `uname -m` map (BASE-03).
- `amd64) jdkArch='x64'; javaDir='amd64'` → `x86_64) jdkArch='x64'; javaDir='amd64'`; `arm64) ...` → `aarch64) ...`.
- Keep the dynamic extracted-dir discovery (`tar -tzf ... | head -1 | cut -d/ -f1`) — do **not** hardcode `jdk-25.0.2+10`.

**Facts to honor:**
- Archive names verified live: `OpenJDK25U-jdk_x64_linux_hotspot_25.0.2_10.tar.gz` and `OpenJDK25U-jdk_aarch64_linux_hotspot_25.0.2_10.tar.gz`.
- The `\$JAVA_HOME` escapes write the literal `$JAVA_HOME` into `java-env.sh` (evaluated at login) — keep the backslash escapes.
- `JAVA_JVM_LIBRARY` and `JDK_HOME` are **not** written to `profile.d` — they live only in the final `ENV` block.

---

### 5. Environment Contract — final `ENV` block (TOOL-05)

**Analog** (`debian-bullseye/Dockerfile`, lines 122-128):

```dockerfile
ENV JAVA_HOME=/usr/lib/jvm/temurin-25-jdk \
    JAVA_INCLUDE_PATH=/usr/lib/jvm/temurin-25-jdk/include \
    JAVA_INCLUDE_PATH2=/usr/lib/jvm/temurin-25-jdk/include/linux \
    JAVA_AWT_INCLUDE_PATH=/usr/lib/jvm/temurin-25-jdk/include \
    JAVA_JVM_LIBRARY=/usr/lib/jvm/temurin-25-jdk/lib/server/libjvm.so \
    JDK_HOME=/usr/lib/jvm/temurin-25-jdk \
    PATH=/usr/lib/jvm/temurin-25-jdk/bin:/usr/local/cargo/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
```

**Target — EL8 form:** **verbatim, byte-for-byte.** No substitution. (This is the same
string on both base images.)

**Facts to honor:**
- `PATH` is written **literally** — no `:$PATH` append (D-07). Only the **top** `ENV`
  block (Phase 1, unchanged) appends `:$PATH`. Keep the two blocks distinct.
- `JAVA_JVM_LIBRARY=.../lib/server/libjvm.so` is arch-independent (modern HotSpot ships
  only the `server` VM).
- `ENV` is image metadata (a directive, not a `RUN`) — do not wrap it in a heredoc.

---

### 6. Runtime Glue (PKG-02)

**Analog** (`debian-bullseye/Dockerfile`, lines 130-134):

```dockerfile
RUN git config --system --add safe.directory '*'

RUN mkdir -p /var/lib/dbus && \
    cat /proc/sys/kernel/random/uuid | tr -d '-' > /var/lib/dbus/machine-id && \
    cp /var/lib/dbus/machine-id /etc/machine-id
```

**Target — EL8 form:** **verbatim.** Both commands are EL8-identical.

**Facts to honor:**
- `git` is installed in Phase 1 step 8; the command is additive (`--add`) — keep it verbatim.
- `cat /proc/sys/kernel/random/uuid | tr -d '-'` and `tr` (coreutils) behave identically on EL8.
- `mkdir -p /var/lib/dbus` is idempotent even though Phase 1 installed `dbus dbus-daemon dbus-tools`.
- Success probe (PKG-02): `cmp -s /var/lib/dbus/machine-id /etc/machine-id && test -s /var/lib/dbus/machine-id`.

---

### 7. Phase 2 verification chain (append after runtime glue)

Mirrors Phase 1 step 9 — one fail-fast heredoc asserting all five success criteria.
Source: `02-RESEARCH.md` "Final Verification Chain" (recommended; use verbatim):

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

---

## Shared Patterns

### Heredoc + `set -eux` convention
**Source:** `debian-bullseye/Dockerfile` (whole file) + `01-PATTERNS.md`
**Apply to:** mold, Node, Rust, JDK blocks and the verification chain.
- Multi-command blocks: `RUN <<EOF` + blank line + `set -eux` + blank line + body + blank line + `EOF`.
- Plain single-line `RUN` for one-offs (repo steps already done in Phase 1; runtime glue stays plain `RUN`).
- Continuation lists (`\`): 4-space indent, trailing ` \` on all but the last line.

### Version pins as in-block shell vars (not `ARG`s)
**Source:** `debian-bullseye/Dockerfile` lines 52-53, 79, 104-105 + `01-PATTERNS.md` §5
**Apply to:** every toolchain block.
- `moldVersion="2.42.0"`, `jdkReleaseTag="jdk-25.0.2+10"`, `url=...1.28.2...` are shell
  variables inside the heredoc — never Dockerfile `ARG`s.

### `wget -q` → verify → extract → cleanup → probe
**Source:** `01-PATTERNS.md` + analog
**Apply to:** mold, Rust, JDK blocks.
- `wget -q` the asset → (rust only) `sha256sum -c` → `tar -xzf` → `rm` archive → `--version` probe, all in the same `RUN`.

### `uname -m` per-block case maps with hard `exit 1` default
**Source:** RESEARCH.md Pattern 2
**Apply to:** mold, Rust, JDK blocks.
- Each block independently runs `case "$(uname -m)" in x86_64) … aarch64) … *) exit 1 ;; esac`.
- Match the **full** string — do **not** copy the analog's `${dpkgArch##*-}` suffix strip.

### Cache cleanup in the same layer
**Source:** `01-PATTERNS.md` + RESEARCH.md
**Apply to:** Node block (`dnf clean all`), and tarball blocks (`rm` the archive in the same `RUN`).
- Do not move cleanup into a later layer — Docker layers are immutable.
- Do **not** remove `/var/lib/dnf` or repo metadata (still used at build time).

### Comment convention (why + revert)
**Source:** `01-PATTERNS.md` §6 + analog lines 42-44
**Apply to:** mold, Node, Rust, JDK blocks.
- Each block opens with a `#` comment explaining **why** (not what) and, where relevant,
  the revert command (e.g. `update-alternatives --set ld /usr/bin/ld.bfd`).

### Supply-chain trust
**Source:** RESEARCH.md "Package Legitimacy Audit"
**Apply to:** all toolchain blocks.
- Only upstream tarballs / official vendor repos over TLS; `gpgcheck=1` on NodeSource (set in Phase 1).
- SHA256-pin **only** rustup (matches the analog). Do **not** add mold/Temurin pins without a user decision (deviates from parity).

---

## Key Difference Table (bullseye vs almalinux-8 toolchain layers)

| Aspect | `debian-bullseye/Dockerfile` (analog) | `almalinux-8/Dockerfile` (target) |
|--------|--------------------------------------|-----------------------------------|
| Base | `debian:bullseye` (glibc 2.31) | `almalinux:8` (glibc 2.28) |
| Arch detection | `dpkg --print-architecture` + `${dpkgArch##*-}` → `amd64`/`arm64`/`armhf`/`i386` | `case "$(uname -m)"` full-string → `x86_64`/`aarch64` only |
| mold block | `amd64→x86_64`, `arm64→aarch64` arms | `x86_64→x86_64`, `aarch64→aarch64` arms; rest unchanged |
| Node install | `curl ... deb.nodesource.com/setup_24.x \| sudo -E bash -` + `sudo apt install -y nodejs` (inside mold heredoc) | `dnf install -y nodejs` (own heredoc; repo enabled Phase 1 step 5) |
| Node verification | none in analog | `node --version` + `node -e 'process.exit(0)'` clean-exit probe (D-02) |
| Rust block | 4 arms incl. `armhf`/`i386` (rustup SHA256s present) | 2 arms only; `armhf`/`i386` arms deleted (BASE-03); SHA256s unchanged |
| JDK block | 5 arms incl. `armhf`/`i386` error arms | 3 arms; error arms deleted (unreachable); recipe unchanged |
| final `ENV` block | literal `PATH`, full JAVA env | **verbatim** — no change |
| runtime glue | `git safe.directory` + machine-id seed | **verbatim** — no change |
| `update-alternatives` shim | present in base | needs `chkconfig` (installed Phase 1 step 1) — already satisfied |
| Verification gate | none | appended `step 10` heredoc asserting all 5 success criteria |

---

## No Analog Found

None — the single file to modify has an exact analog (`debian-bullseye/Dockerfile`),
and the per-block EL8 target forms are already specified in `02-RESEARCH.md`.

## Metadata

**Analog search scope:** `debian-bullseye/Dockerfile` (parity source of truth), `almalinux-8/Dockerfile` (target), `.planning/phases/01-base-package-install/01-PATTERNS.md`, `.planning/phases/02-toolchain-install/02-RESEARCH.md`
**Files scanned:** 5 (debian-bullseye/Dockerfile, almalinux-8/Dockerfile, 01-PATTERNS.md, 02-RESEARCH.md, 02-CONTEXT.md)
**Pattern extraction date:** 2026-09-08
