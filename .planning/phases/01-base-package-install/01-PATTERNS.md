# Phase 1: Base & Package Install - Pattern Map

**Mapped:** 2026-09-08
**Files analyzed:** 1
**Analogs found:** 1 / 1

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `almalinux-8/Dockerfile` | Dockerfile / CI build-image definition | build-time layer stack (batch image assembly) | `debian-bullseye/Dockerfile` | exact |

> Single-file phase. `almalinux-8/Dockerfile` is a **new** file created bottom-up as a
> dnf-based port of the apt-based `debian-bullseye/Dockerfile`. Same role, same data
> flow (ordered `RUN` layers: base → repo enablement → package install → cleanup),
> different package manager. This is the unambiguously correct analog.

---

## Pattern Assignments

### `almalinux-8/Dockerfile` (Dockerfile, build-time layer stack)

**Analog:** `debian-bullseye/Dockerfile` (134 lines) — the authoritative parity source of truth.

---

#### 1. Frontmatter + base image

**Analog** (`debian-bullseye/Dockerfile`, lines 1-2):

```dockerfile
# syntax=docker/dockerfile:1
FROM debian:bullseye
```

**Target** (`almalinux-8/Dockerfile`):

```dockerfile
# syntax=docker/dockerfile:1
FROM almalinux:8
```

- Keep the `# syntax=docker/dockerfile:1` frontmatter line verbatim — it enables the
  BuildKit heredoc syntax the rest of the file relies on.
- `FROM` is the very next line, no labels, no `ARG`, no comments between frontmatter
  and `FROM`.
- `almalinux:8` is the rolling multi-arch tag (amd64 + arm64 manifest; glibc 2.28).

---

#### 2. ENV contract (top of file)

**Analog** (`debian-bullseye/Dockerfile`, lines 4-7):

```dockerfile
ENV RUSTUP_HOME=/usr/local/rustup \
    CARGO_HOME=/usr/local/cargo \
    PATH=/usr/local/cargo/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH \
    RUST_VERSION=1.87.0
```

Conventions to replicate:
- Multi-line `ENV` with `\` line continuations; continuation lines indented **4 spaces**.
- `RUST_VERSION` is the toolchain pin consumed by Phase 2 (rustup) — carry it forward
  unchanged even though Phase 1 doesn't use it yet.
- **Flag for the executor:** RESEARCH.md's EL8 recipe writes this `PATH` literally
  (hardcoded, no `$PATH` append). The analog appends `:$PATH` to preserve the base
  image's own `PATH`. Follow the **analog** (`...:/bin:$PATH`) — appending is the
  safer, base-image-preserving form and matches the existing file byte-for-byte.

---

#### 3. Repo enablement (single-line `RUN`, before install)

**Analog** (`debian-bullseye/Dockerfile`, line 9):

```dockerfile
RUN echo 'deb http://archive.debian.org/debian bullseye-backports main' > /etc/apt/sources.list.d/backports.list
```

Convention: repo configuration is a **separate, single-line `RUN` before the package
install layer** — it mutates `/etc/...` (repo config) and is kept out of the install
transaction for layer-cache stability.

**Target — dnf equivalent** (from RESEARCH.md "Exact Ordered dnf Recipe"; ordered,
each step isolated, `dnf clean all` in the same layer as any `dnf install`):

```dockerfile
# 1) Bootstrap dnf tooling + base utilities. dnf config-manager lives in
#    dnf-plugins-core and is NOT guaranteed present in the minimal image.
RUN dnf install -y \
        dnf-plugins-core \
        wget curl tar gzip xz ca-certificates \
        chkconfig \
    && dnf clean all

# 2) EPEL (pulled from Extras, which almalinux:8 ships enabled)
RUN dnf install -y epel-release \
    && dnf clean all

# 3) PowerTools / CodeReady Builder. AlmaLinux 8 repo id = 'powertools' (NOT 'crb')
RUN dnf config-manager --set-enabled powertools

# 4) GitHub CLI official rpm repo (gh is in no EL repo)
RUN dnf config-manager --add-repo https://cli.github.com/packages/rpm/gh-cli.repo

# 5) NodeSource 24.x rpm repo (nodejs itself is installed in Phase 2)
RUN curl -fsSL https://rpm.nodesource.com/setup_24.x -o /tmp/nodesource_setup.sh \
    && bash /tmp/nodesource_setup.sh \
    && rm /tmp/nodesource_setup.sh \
    && dnf clean all

# 6) Enable AppStream modules before install (clang is delivered ONLY via llvm-toolset)
RUN dnf module enable llvm-toolset -y
```

Rules the executor must honor:
- `dnf-plugins-core` installs **before** any `dnf config-manager` call.
- `--set-enabled powertools` on EL8 — never `crb` (that's AlmaLinux 9).
- `gpgcheck=1` everywhere; **never** `--nogpgcheck`. `curl -fsSL` for the NodeSource
  script, then delete it after use.
- `dnf clean all` in the same `RUN` layer as each `dnf install` (steps 1, 2, 5).

---

#### 4. Single package-install layer (heredoc + `set -eux`)

**Analog** (`debian-bullseye/Dockerfile`, lines 11-36) — the canonical shell-form
convention for the big install block:

```dockerfile
RUN <<EOF

set -eux

apt update
apt install -y -t bullseye-backports \
    sudo \
    pkg-config \
    git \
    ruby-full \
    clang \
    cmake \
    gh \
    wget \
    curl \
    libcurl4-openssl-dev \
    libsecret-1-dev \
    dbus \
    gnome-keyring \
    ninja-build \
    libvulkan-dev \
    libgtk-3-dev \
    jq \
    libatomic1

EOF
```

Structural conventions extracted (replicate all of these):
- `RUN <<EOF` on its own line, **blank line** after it, then `set -eux`, **blank line**,
  then the shell body, **blank line**, then `EOF` on its own line.
- `set -eux` at the top of every heredoc block (fail-fast + echo every command).
- One single package-manager invocation for **all** distro packages; the package list
  is one-per-line, indented 4 spaces, every line except the last terminated with ` \`.
- `apt update` precedes `apt install` (analog). dnf equivalent needs no separate
  metadata-refresh line (dnf refreshes automatically), so the dnf block starts at the
  install itself.

**Target — dnf install layer** (from RESEARCH.md step 7; single transaction, cache
cleaned in the SAME layer):

```dockerfile
# 7) Single install transaction — full mapped package set.
#    nodejs deliberately EXCLUDED (Phase 2). chkconfig/openssl-devel are build essentials.
RUN dnf install -y \
        sudo \
        pkgconf-pkg-config \
        git \
        ruby ruby-devel \
        clang \
        cmake \
        make gcc gcc-c++ binutils \
        gh \
        openssl-devel \
        libcurl-devel \
        libsecret-devel \
        dbus dbus-daemon dbus-tools \
        gnome-keyring \
        ninja-build \
        vulkan-loader vulkan-loader-devel vulkan-headers \
        gtk3-devel \
        jq \
        libatomic \
    && dnf clean all \
    && rm -rf /var/cache/dnf
```

- Package list is the EL8 re-mapping of the analog's apt list, plus the EL8
  build-essentials (`make gcc gcc-c++ binutils`, `openssl-devel`) that Debian pulled
  implicitly.
- `dnf clean all` **and** `rm -rf /var/cache/dnf` live in the same `RUN` layer — Docker
  layers are immutable, so a later-layer clean cannot shrink this layer's cache.
- Do **not** remove `/var/lib/dnf` or repo metadata — Phase 2 still runs `dnf install
  nodejs` and may `dnf` again.
- Keep this volatile package layer as the **last** dnf layer so repo setup (steps 1-6)
  stays cacheable when the package list changes.
- **Style note for the executor:** the analog wraps the install in a `RUN <<EOF` +
  `set -eux` heredoc; RESEARCH.md's recipe shows a plain `RUN ... \` continuation
  instead. Both are valid — recommend the **heredoc + `set -eux`** form to match the
  analog exactly, but do not mix forms in the same block.

---

#### 5. Toolchain version pins as shell vars (Phase 2 pattern, noted for continuity)

**Analog** (`debian-bullseye/Dockerfile`, lines 52-59) — the convention for pinning
and installing an upstream tarball:

```dockerfile
moldVersion="2.42.0"; \
moldArchive="mold-${moldVersion}-${moldArch}-linux.tar.gz"; \
cd /tmp; \
wget -q "https://github.com/rui314/mold/releases/download/v${moldVersion}/${moldArchive}"; \
tar -xzf "${moldArchive}" -C /usr/local --strip-components=1; \
rm "${moldArchive}"; \
update-alternatives --install /usr/bin/ld ld /usr/local/bin/ld.mold 100; \
ld --version;
```

- Version pins are shell variables (`moldVersion="2.42.0"`) inside the heredoc, not
  Dockerfile `ARG`s.
- `wget -q` → `tar -xzf` → `rm archive` → verify (`ld --version`).
- **Phase 2 only** — Phase 1 does not touch these. Recorded here so the executor knows
  the convention continues in later layers and does not invent a new one.

---

#### 6. Comment convention (rationale + revert instructions)

**Analog** (`debian-bullseye/Dockerfile`, lines 42-44):

```dockerfile
# mold: bullseye has no mold package, and clang 11 predates -fuse-ld=mold, so install the
# upstream static build and register it as the default ld. Revert with
# `update-alternatives --set ld /usr/bin/ld.bfd` if a link ever misbehaves.
```

Replicate: each non-obvious step gets a `#` comment explaining **why**, not what, and
where relevant the **revert/un-do** command. Apply this to the EL8 repo-enablement
steps (e.g. why `powertools` not `crb`; why `llvm-toolset` must precede `dnf install
clang`).

---

#### 7. Runtime glue (Phase 2 pattern, noted for continuity)

**Analog** (`debian-bullseye/Dockerfile`, lines 130-134):

```dockerfile
RUN git config --system --add safe.directory '*'

RUN mkdir -p /var/lib/dbus && \
    cat /proc/sys/kernel/random/uuid | tr -d '-' > /var/lib/dbus/machine-id && \
    cp /var/lib/dbus/machine-id /etc/machine-id
```

- Plain single-line `RUN`s, `&&` continuation for the multi-command dbus block,
  continuation lines indented 4 spaces.
- **Phase 2 only** — Phase 1 installs the `dbus`/`dbus-daemon`/`dbus-tools` **packages**
  but does not seed `machine-id` (that is PKG-02).

---

## Shared Patterns

### Dockerfile shell-form & heredoc convention
**Source:** `debian-bullseye/Dockerfile` (whole file)
**Apply to:** `almalinux-8/Dockerfile`
- Multi-command blocks: `RUN <<EOF` + blank line + `set -eux` + blank line + body +
  blank line + `EOF`.
- Short single-purpose steps: plain `RUN cmd` (or `RUN cmd && cmd` with 4-space-indented
  continuations).
- Continuation lists (`\`): one item per line, 4-space indent, trailing ` \` on all but
  the last item.
- No labels, no `ARG`, no `WORKDIR`, no `USER` — the image runs as root throughout.

### Cache cleanup in the same layer
**Source:** RESEARCH.md "Build-Size / Cache-Cleanup Strategy"
**Apply to:** every `dnf install` layer
- `dnf clean all` in the same `RUN` as the install; `rm -rf /var/cache/dnf` as
  belt-and-suspenders on the big layer. Never clean in a later layer.

### Supply-chain trust
**Source:** RESEARCH.md "Package Legitimacy Audit" + Pitfall 7
**Apply to:** all repo-enablement + install layers
- `gpgcheck=1` on all repos; never `--nogpgcheck`; only official AlmaLinux repos +
  EPEL + two first-party vendor repos (gh-cli, NodeSource); `curl -fsSL` for the
  NodeSource script, delete it after use.

### Repo id correctness
**Source:** RESEARCH.md Pitfalls 1-3 + "Don't Hand-Roll"
**Apply to:** repo enablement + install layers
- `powertools` (not `crb`) on AlmaLinux 8; `dnf module enable llvm-toolset -y` before
  `dnf install clang`; `gh` only from the gh-cli repo; `pkgconf-pkg-config` provides
  `pkg-config`.

---

## Key Difference (the whole point of the port)

| Aspect | `debian-bullseye/Dockerfile` | `almalinux-8/Dockerfile` (target) |
|--------|------------------------------|-----------------------------------|
| Package manager | `apt` / `apt-get` | `dnf` |
| Base | `debian:bullseye` (glibc 2.31) | `almalinux:8` (glibc 2.28) |
| Repo enablement | `echo 'deb ...' > sources.list.d/backports.list` | `dnf config-manager --set-enabled powertools` + `--add-repo gh-cli.repo` + NodeSource script + `dnf module enable llvm-toolset` |
| Arch detection | `dpkg --print-architecture` (`amd64`/`arm64`) | `uname -m` (`x86_64`/`aarch64`) — Phase 2 |
| Node repo | `deb.nodesource.com/setup_24.x` piped to `sudo -E bash -` | `rpm.nodesource.com/setup_24.x` saved to `/tmp`, run with `bash`, then deleted |
| Cache cleanup | (apt auto-cleans) | `dnf clean all` + `rm -rf /var/cache/dnf` in the install layer |
| Package names | `pkg-config`, `ruby-full`, `libcurl4-openssl-dev`, `libsecret-1-dev`, `libvulkan-dev`, `libgtk-3-dev`, `libatomic1` | `pkgconf-pkg-config`, `ruby ruby-devel`, `libcurl-devel`, `libsecret-devel`, `vulkan-loader vulkan-loader-devel vulkan-headers`, `gtk3-devel`, `libatomic` |
| EOL hack | `Acquire::Check-Valid-Until=false` backports workaround | **deleted** — AlmaLinux 8 supported to May 2029 |

---

## Build-Time Validation Checklist (must be encoded as verification steps in the plan)

Per RESEARCH.md, these repo placements cannot be resolved locally and must be checked
at `docker build` time:

1. `dnf info libsecret-devel` — repo unresolved (AppStream vs BaseOS).
2. `dnf info libcurl-devel` — expect PowerTools/CRB.
3. `dnf info vulkan-loader-devel` — assumed AppStream alongside loader.
4. `dnf repolist` — confirm repo id `powertools`; fallback: write
   `/etc/yum.repos.d/almalinux-powertools.repo`.
5. `dnf module list llvm-toolset` — expect default stream 17.0.6 on 8.10.
6. `ruby` stream — pin `ruby:3.1` (or `3.3`); do not accept silent default 2.5 (EOL).
7. Keep `epel-release` (satisfies BASE-02); install all packages from native repos
   without `--enablerepo=epel`.
8. `gnome-keyring` + `vulkan-headers` aarch64 availability — Phase 4 re-verifies.
9. `docker images` size check after `dnf clean all` — comparable to `debian-bullseye`.

---

## No Analog Found

None — the single file to create has an exact analog (`debian-bullseye/Dockerfile`).

## Metadata

**Analog search scope:** workspace root (`debian-bullseye/Dockerfile`), `.planning/research/*`, `.planning/phases/01-base-package-install/*`
**Files scanned:** 6 (RESEARCH.md, STACK.md, ARCHITECTURE.md, ROADMAP.md, README.md, debian-bullseye/Dockerfile)
**Pattern extraction date:** 2026-09-08
