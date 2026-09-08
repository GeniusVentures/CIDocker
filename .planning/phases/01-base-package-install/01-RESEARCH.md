# Phase 1: Base & Package Install - Research

**Researched:** 2026-09-08
**Domain:** AlmaLinux 8 CI build image — base + dnf repo enablement + full EL8 package set (parity port of `debian-bullseye/Dockerfile`)
**Confidence:** HIGH (base/repo/package mapping shape); MEDIUM on 4 residual per-package repo placements and the Ruby stream — flagged inline and listed in the Build-Time Validation Checklist.

## Summary

Phase 1 produces the bottom half of a new `almalinux-8/Dockerfile`: `FROM almalinux:8` (glibc 2.28, multi-arch `amd64`+`arm64` manifest), an ordered dnf repo-enablement sequence, and a single dnf install transaction carrying every EL8 equivalent of the bullseye system-package set, finished with `dnf clean all`. This phase installs **system packages and repositories only** — mold, Node, Rust, and JDK (the upstream-tarball toolchain) are Phase 2 and are deliberately excluded.

The prior research files (`research/STACK.md`, `PITFALLS.md`, `ARCHITECTURE.md`, `FEATURES.md`, `SUMMARY.md`) already contain the ordered recipe and a Debian→EL8 mapping, but they **conflict with each other on four repo placements** (`ninja-build`, `libcurl-devel`, `libsecret-devel`, Vulkan). This research resolves those conflicts against live Repology data where possible:

- **`ninja-build` → PowerTools/CRB** (1.8.2) — VERIFIED via Repology. STACK.md's "AppStream" was **wrong**; PITFALLS.md was right.
- **`vulkan-loader` + `vulkan-headers` → AppStream** (1.3.283.0) — VERIFIED via Repology. EPEL is **not** required for Vulkan; ARCHITECTURE/SUMMARY correction stands.
- **`gnome-keyring` → AppStream** (3.28.2) — VERIFIED via Repology.
- **`libcurl-devel` → PowerTools/CRB** — runtime `curl`/`libcurl` (7.61.1) is BaseOS (VERIFIED via Repology); the `-devel` package is the canonical CRB/PowerTools split (STACK HIGH + PITFALLS agree). ARCHITECTURE.md's "BaseOS" claim refers to the runtime lib, not the dev package. **Flag for build-time `dnf info` confirmation.**
- **`libsecret-devel`** — runtime `libsecret` 0.18.6 is BaseOS (VERIFIED via Repology); the `-devel` sub-package's repo is still ambiguous across sources (STACK says AppStream, PITFALLS says BaseOS). **Unresolved — must be validated at build time.**

**Primary recommendation:** Write a single `almalinux-8/Dockerfile` that (1) bootstraps `dnf-plugins-core` + base utilities, (2) enables `epel-release` → `powertools` → GitHub CLI repo → NodeSource repo (per BASE-02 order), (3) enables the `llvm-toolset` module, and (4) runs one `dnf install -y` with the full mapped package list followed by `dnf clean all` in the same `RUN` layer. Encode every unresolved repo placement as an explicit `dnf repolist`/`dnf info`/`docker build` verification step so failures surface at build time, not at first CI use.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Base OS + glibc 2.28 | Base image (`FROM almalinux:8`) | — | The distro itself owns glibc; no Dockerfile code can change it. |
| dnf tooling bootstrap (`config-manager`) | Repo-enablement layer | — | `dnf-plugins-core` must exist before any `dnf config-manager` call. |
| Repo enablement (EPEL/PowerTools/gh/NodeSource) | Repo-enablement layer | — | Mutates `/etc/yum.repos.d/*`; isolated from package install for cache stability. |
| Module enablement (`llvm-toolset`, `ruby`) | Repo-enablement layer | — | Module state is a filesystem change that must precede `dnf install clang`. |
| All distro packages | Package-install layer (single transaction) | — | One `dnf install -y` mirrors the bullseye single `apt install` block; avoids partial-install states. |
| dnf cache cleanup | Package-install layer (same `RUN`) | — | Cleaning in a later layer cannot shrink an earlier layer's cache. |
| Toolchain (mold/Node/Rust/JDK) | Phase 2 layers | — | Upstream tarballs; depend on Phase 1's `wget`/`curl`/`tar`/`ca-certificates`. |

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| BASE-01 | Image is based on `almalinux:8` (glibc 2.28) | `FROM almalinux:8`; Docker Official Image, multi-arch manifest, glibc 2.28 (older than bullseye's 2.31, satisfying the ≤2.31 constraint). Verify with `ldd --version` ⇒ "ldd (GNU libc) 2.28". |
| BASE-02 | dnf repositories enabled in order — `dnf-plugins-core`, `epel-release`, PowerTools/CRB, GitHub CLI repo, NodeSource | Ordered recipe section below. `dnf config-manager` requires `dnf-plugins-core` first; `powertools` is the AlmaLinux 8 CRB repo id; `gh-cli.repo` is the only source of `gh`; NodeSource rpm script adds the `nodistro`/`el` repo. |
| PKG-01 | Installs EL8 equivalents of every bullseye package + `gcc`/`gcc-c++`/`make`/`binutils` | Full mapping table + single-transaction package list below. Two extra build-essential packages (`openssl-devel`, `chkconfig`) come from STACK.md and are recommended additions (flagged). |
</phase_requirements>

## Package Mapping — Debian → EL8 (resolved)

Every package the bullseye `Dockerfile` installs via `apt`, mapped to its EL8 dnf package + repo. Verification tags: `[VERIFIED: repology.org]` (confirmed this session), `[CITED: research/STACK.md]` / `[CITED: research/PITFALLS.md]` (prior-session verification against live repo listings), `[ASSUMED]` (not independently confirmed).

| Debian package (bullseye) | EL8 dnf package | Repo | Verification | Notes |
|---------------------------|-----------------|------|--------------|-------|
| `sudo` | `sudo` | BaseOS | [CITED: STACK] | Same name. |
| `pkg-config` | `pkgconf-pkg-config` | AppStream | [CITED: STACK] | EL8 has no `pkg-config` package; this provides `/usr/bin/pkg-config` + `pkgconfig` virtual. |
| `git` | `git` | AppStream | [CITED: STACK] | 2.43.x on 8.10. |
| `ruby-full` | `ruby` + `ruby-devel` | AppStream (module) | [CITED: STACK] | No `ruby-full`. Default stream 2.5; 3.0/3.1/3.3 available. `ruby-devel` supplies C-extension headers. **Stream choice unresolved — see Open Questions.** |
| `clang` | `clang` | AppStream (`llvm-toolset` module) | [CITED: STACK + PITFALLS] | Module only — plain `dnf install clang` fails without enabling. Default stream 17.0.6 on 8.10; pulls `clang-libs`, `llvm`, `libomp`. |
| `cmake` | `cmake` | AppStream | [CITED: STACK] | 3.26.5 on 8.10. |
| `gh` | `gh` | **GitHub CLI rpm repo** | [CITED: STACK + PITFALLS] | In no EL repo. `cli.github.com/packages/rpm/gh-cli.repo`; repodata carries x86_64 + aarch64. |
| `wget` | `wget` | BaseOS | [CITED: STACK] | Not in minimal image by default — install explicitly. |
| `curl` | `curl` | BaseOS | [VERIFIED: repology.org] | 7.61.1. Minimal image ships only `curl-minimal`, if any — install full `curl`. |
| `libcurl4-openssl-dev` | `libcurl-devel` | **PowerTools/CRB** | [CITED: STACK + PITFALLS] | Runtime `libcurl` is BaseOS; the `-devel` package is the canonical CRB split. ARCHITECTURE.md's "BaseOS" row refers to runtime lib. **Flag build-time verify.** |
| `libsecret-1-dev` | `libsecret-devel` | AppStream (STACK) **vs** BaseOS (PITFALLS) | runtime `libsecret` 0.18.6 [VERIFIED: repology.org] in BaseOS; `-devel` **UNRESOLVED** | **Must validate at build time (`dnf info libsecret-devel`).** |
| `dbus` | `dbus` + `dbus-daemon` + `dbus-tools` | BaseOS | [CITED: PITFALLS] | EL8 splits `dbus-daemon`/`dbus-tools` out of `dbus`. `dbus-launch` is `dbus-x11` (only if actually needed — skip). |
| `gnome-keyring` | `gnome-keyring` | AppStream | [VERIFIED: repology.org] | 3.28.2 (vs bullseye 3.36.0). |
| `ninja-build` | `ninja-build` | **PowerTools/CRB** | [VERIFIED: repology.org] | 1.8.2 (vs bullseye 1.10.1). **STACK.md's "AppStream" is superseded.** |
| `libvulkan-dev` | `vulkan-loader` + `vulkan-loader-devel` + `vulkan-headers` | AppStream | loader + headers [VERIFIED: repology.org] (1.3.283.0); `-devel` [ASSUMED same repo] | EL8 splits Vulkan. EPEL **not** required. `vulkan-loader-devel` sub-package placement assumed alongside loader — flag. |
| `libgtk-3-dev` | `gtk3-devel` | AppStream | [CITED: STACK + PITFALLS] | 3.22.30 (vs bullseye 3.24.38 — the GTK gap; Phase 3 concern). Pulls atk/pango/cairo/gdk-pixbuf2/glib2 `-devel` transitively. |
| `jq` | `jq` | AppStream | [CITED: STACK] | (`jq-devel` is CRB; not needed.) |
| `libatomic1` | `libatomic` | BaseOS | [CITED: STACK + PITFALLS] | gcc runtime lib. |

### Additional EL8 build-essential packages (Debian pulled these implicitly)

| Package | Repo | Why | Verification |
|---------|------|-----|--------------|
| `gcc` + `gcc-c++` | AppStream | 8.5.0 — provides `cc`/`c++`, `glibc-devel`, `glibc-headers`, `libstdc++-devel` (headers every native build needs). | [CITED: STACK] |
| `make` | BaseOS | cmake/cargo build scripts invoke `make`. | [CITED: STACK] |
| `binutils` | BaseOS | `ld`, `as`, `ar`, `nm` — required even when clang compiles. | [CITED: STACK] |
| `openssl-devel` | BaseOS/AppStream (MEDIUM) | Rust `openssl-sys` crates + CMake TLS deps link against it; bullseye pulled it via `libcurl4-openssl-dev`. **Not in literal PKG-01 text — recommended addition.** | [CITED: STACK] |
| `chkconfig` | BaseOS | Provides `/usr/sbin/update-alternatives` — needed by Phase 2's mold `ld` shim. Install in bootstrap layer. | [CITED: STACK] |
| `wget curl tar gzip xz ca-certificates` | BaseOS | Download/HTTPS tooling for Phase 2 tarball installs; `ca-certificates` enables TLS to github.com/static.rust-lang.org. | [CITED: STACK] |

## Exact Ordered dnf Recipe

```dockerfile
# syntax=docker/dockerfile:1
FROM almalinux:8

# Env contract carried forward from debian-bullseye (consumed by Phase 2+)
ENV RUSTUP_HOME=/usr/local/rustup \
    CARGO_HOME=/usr/local/cargo \
    PATH=/usr/local/cargo/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
    RUST_VERSION=1.87.0

# 1) Bootstrap dnf tooling + base utilities (idempotent, ordered)
#    dnf config-manager lives in dnf-plugins-core and is NOT guaranteed in the minimal image.
RUN dnf install -y \
        dnf-plugins-core \
        wget curl tar gzip xz ca-certificates \
        chkconfig \
    && dnf clean all

# 2) EPEL (pulled from the Extras repo, which almalinux:8 ships enabled).
#    Kept per BASE-02 order. Research note: EPEL is NOT strictly required for the
#    current package set (Vulkan is AppStream) — it is a documented fallback source.
RUN dnf install -y epel-release \
    && dnf clean all

# 3) PowerTools / CodeReady Builder. AlmaLinux 8 repo id = 'powertools' (NOT 'crb').
#    Source of libcurl-devel + ninja-build.
RUN dnf config-manager --set-enabled powertools

# 4) GitHub CLI official rpm repo (gh is in no EL repo)
RUN dnf config-manager --add-repo https://cli.github.com/packages/rpm/gh-cli.repo

# 5) NodeSource 24.x rpm repo (enabled here per BASE-02; nodejs is installed in Phase 2)
RUN curl -fsSL https://rpm.nodesource.com/setup_24.x -o /tmp/nodesource_setup.sh \
    && bash /tmp/nodesource_setup.sh \
    && rm /tmp/nodesource_setup.sh \
    && dnf clean all

# 6) Enable AppStream modules before install.
#    clang is delivered ONLY via the llvm-toolset module (default stream 17.0.6 on 8.10).
RUN dnf module enable llvm-toolset -y

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

**Ordering rationale (why this exact sequence):**
1. `dnf-plugins-core` must precede every `dnf config-manager` call.
2. `epel-release` is installed from Extras (already enabled in the base image).
3. `powertools` (CRB) must be enabled before `libcurl-devel`/`ninja-build` resolve.
4. `gh-cli.repo` must precede `dnf install gh`.
5. NodeSource must precede `dnf install nodejs` (Phase 2) and needs `curl` from step 1.
6. `llvm-toolset` must be enabled before `dnf install clang`.
7. The install itself is one transaction — `dnf` resolves cross-repo dependencies atomically.

**If step 3 reports `Unknown repo 'powertools'`:** the container's repo file names it differently. Write `/etc/yum.repos.d/almalinux-powertools.repo` pointing at `https://repo.almalinux.org/almalinux/8/PowerTools/$basearch/os/` (`enabled=1`, mirror the `almalinux.repo` structure) and retry. Confirm the actual id with `dnf repolist` at build time.

## Build-Size / Cache-Cleanup Strategy

- **`dnf clean all` must run in the SAME `RUN` layer as each `dnf install`.** Docker layers are immutable — cleaning in a later `RUN` does not shrink an earlier layer's cache. Apply it to steps 1, 2, 5, and 7 above.
- **Add `rm -rf /var/cache/dnf` as a belt-and-suspenders** on the big install layer (step 7); `dnf clean all` normally covers `/var/cache/dnf` but the explicit `rm` is cheap insurance.
- **Do NOT remove `/var/lib/dnf` or repo metadata needed by later phases** — Phase 2 still runs `dnf install nodejs` (NodeSource) and may `dnf` again; only clean the *cache*, not the repo configs.
- **Layer-cache ordering:** keep the volatile package list (step 7) as the LAST dnf layer. Steps 1–6 (bootstrap + repos + module enablement) change rarely, so edits to the package list do not re-run repo setup. Toolchain layers (Phase 2) will be appended AFTER step 7, so they never invalidate the package layer.
- **Do not add an unconditional `dnf upgrade -y`.** It bloats the image, adds non-determinism, and the base `:8` tag already carries rolling security updates. If a CVE-driven upgrade is ever required, it is a deliberate, separate change.

## Package Legitimacy Audit

> This phase installs **zero npm/PyPI/crates packages** — `slopcheck` is not applicable. All packages are official RPMs from the AlmaLinux/RHEL base repos plus two first-party vendor repos. Legitimacy for third-party repos is established by provenance + GPG, not slopcheck.

| Repo / Package source | Type | Provenance | GPG | Disposition |
|-----------------------|------|-----------|-----|-------------|
| AlmaLinux BaseOS / AppStream / PowerTools / Extras | Distro official | `repo.almalinux.org` (AlmaLinux project) | Signed, `gpgcheck=1` by default | Approved |
| `epel-release` (EPEL) | Fedora EPEL project | `dl.fedoraproject.org/pub/epel` | Signed via `epel-release` shipped key | Approved (fallback source) |
| GitHub CLI rpm repo (`gh-cli.repo`) | First-party vendor (GitHub) | `cli.github.com/packages/rpm` | `gpgcheck=1` + key URL in the repo file | Approved |
| NodeSource (`rpm.nodesource.com/setup_24.x`) | First-party vendor | NodeSource official script | Script writes repo with GPG key | Approved — **pin review**: the script is fetched over HTTPS; do not add `--nogpgcheck` |

**Explicit security requirements carried into the plan:**
- Keep `gpgcheck=1` on all repos (never `gpgcheck=0` / `--nogpgcheck`).
- Fetch the NodeSource setup script via `curl -fsSL` (fail on error) and delete it after use.
- Only `epel-release` (official) and the two first-party vendor repos are added; no unknown third-party repos.

## Architecture Patterns

### Recommended Project Structure

```
W:\gnus\CIDocker\
├── README.md                 # unchanged
├── .planning\                # GSD artifacts (not part of image builds)
├── debian-bullseye\
│   └── Dockerfile            # existing image (kept during grace period)
└── almalinux-8\              # NEW — mirrors debian-bullseye convention
    └── Dockerfile            # the port; single file, same heredoc style
```

Directory name is lowercase distro + hyphenated major version (`almalinux-8`), exactly mirroring `debian-bullseye`. No `docker-compose`, no `Makefile`, no `.dockerignore` — CI keys off the directory name; build orchestration lives in CI, not the repo.

### Pattern 1: One Package-Manager Layer for All Distro Packages
**What:** Every distro package in a single `RUN dnf install -y ...` block (mirrors the bullseye single `apt install` block). Toolchain components (mold/Node/Rust/JDK) are Phase 2 upstream-tarball layers.
**Why:** One transaction avoids partial-install states, maximizes layer-cache hits, and lets dnf resolve cross-repo deps atomically.

### Pattern 2: Repo Enablement Precedes Install
**What:** Non-default sources (EPEL/PowerTools/gh/NodeSource) and module streams (`llvm-toolset`) are enabled in dedicated layers before the install layer.
**Why:** Isolates the "mutate repo config" side effect from package install; keeps the install layer a pure `dnf install`.

### Pattern 3: No arch branching in Phase 1
**What:** All Phase 1 package names are architecture-independent (`x86_64`/`aarch64` both served by the same repo names). Arch-detection (`uname -m` + 2-arm case maps) is a **Phase 2** concern for the tarball toolchain.
**Why:** Do not add dead `armhf`/`i386` branches now — RHEL clones ship neither (BASE-03, enforced in Phase 4).

### Anti-Patterns to Avoid
- **Copying the bullseye `apt`/`backports` layer verbatim** — EL8 has no `dpkg`, no backports repo, different package names (`libcurl-devel`, `pkgconf-pkg-config`). Re-map names; drop the `Acquire::Check-Valid-Until=false` hack entirely.
- **Unconditional `dnf --enablerepo=epel`** — install from native repos first; EPEL is a fallback. Unconditional EPEL pinning can shadow base packages.
- **`--set-enabled crb` on AlmaLinux 8** — `crb` is the AlmaLinux **9** repo id; EL8 uses `powertools`.
- **Cleaning dnf cache in a later layer** — see cache-cleanup strategy above.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Vulkan headers/loader | Build Vulkan headers from source | `vulkan-loader` + `vulkan-loader-devel` + `vulkan-headers` from AppStream | Source builds are fragile for a CI image; packages are versioned and signed. |
| `gh` install | Compile from source or vendor a binary | GitHub CLI official rpm repo | Keeps `gh` updated via dnf; official, GPG-signed, aarch64+x86_64. |
| `pkg-config` | Look for a `pkg-config` RPM | `pkgconf-pkg-config` | EL8 has no `pkg-config` package; `pkgconf-pkg-config` provides the `pkgconfig` virtual + `/usr/bin/pkg-config`. |
| clang | `dnf install clang` without a module | `dnf module enable llvm-toolset` then install `clang` | clang exists only as an AppStream module on EL8. |
| Repo id guessing | Hard-code `crb`/`powertools` without checking | `dnf repolist` at build time + `--set-enabled powertools` | The id differs across EL8 clones; assert rather than assume. |
| Build-essential toolchain | Assume clang alone compiles | Explicitly install `gcc gcc-c++ make binutils` | EL8 does not pull a linker, `make`, or libc headers via clang. |

**Key insight:** every one of these is a distro-packaging reality, not a custom-code opportunity. Hand-rolling any of them (source builds, vendored binaries, guessed repo ids) adds fragility to a reproducibility-critical image with zero benefit.

## Common Pitfalls (Phase-1-relevant)

### Pitfall 1: `ninja-build` lives in PowerTools/CRB, not AppStream
**What goes wrong:** `dnf install ninja-build` fails with `No match for argument` in a default container.
**Why:** Repology confirms `AlmaLinux 8 PowerTools | ninja-build | 1.8.2`; the repo is disabled by default.
**Avoid:** `dnf config-manager --set-enabled powertools` before install; verify with `dnf repolist`.

### Pitfall 2: `gh` is in no EL repo
**What goes wrong:** `dnf install gh` fails; building from source is slow/fragile.
**Avoid:** `dnf config-manager --add-repo https://cli.github.com/packages/rpm/gh-cli.repo` then `dnf install -y gh`.

### Pitfall 3: `clang` is an AppStream module
**What goes wrong:** `dnf install clang` fails with `Error: Unable to find a match: clang` if `llvm-toolset` is not enabled.
**Avoid:** `dnf module enable llvm-toolset -y` first. Verify module state persists into the final image (`clang --version` in a later layer). Default stream 17.0.6 on 8.10.

### Pitfall 4: `libcurl-devel` / `libsecret-devel` repo ambiguity
**What goes wrong:** Assuming the wrong repo leads to `No match for argument` or a resolution surprise.
**Avoid:** Both are `-devel` packages whose runtime libs are BaseOS. `libcurl-devel` is CRB/PowerTools (canonical). `libsecret-devel`'s repo is unresolved across sources — **verify with `dnf info libsecret-devel` at build time** and adjust the enablement step if needed.

### Pitfall 5: dbus/keyring need explicit sub-packages
**What goes wrong:** EL8's `dbus` alone lacks `dbus-send`/`dbus-run-session`; keyring-dependent CI steps hang silently.
**Avoid:** Install `dbus dbus-daemon dbus-tools`. (The machine-id seeding is PKG-02 / Phase 2, but the packages belong here.)

### Pitfall 6: Un-cleaned dnf cache balloons the image
**What goes wrong:** The image is hundreds of MB larger than `debian-bullseye`.
**Avoid:** `dnf clean all` (+ `rm -rf /var/cache/dnf`) in the same `RUN` layer as the install.

### Pitfall 7: GPG / repo trust on third-party repos
**What goes wrong:** `dnf` aborts or, worse, a tampered package is accepted.
**Avoid:** Keep `gpgcheck=1`; import keys via the repo files (gh, NodeSource) and `epel-release`; never pass `--nogpgcheck`.

## Code Examples

### Verifying BASE-01 (glibc 2.28) inside the built image
```bash
# Success criterion 1: reports 2.28
ldd --version | head -1        # => ldd (GNU libc) 2.28
```

### Verifying BASE-02 (repos enabled, in order) inside the build
```bash
dnf repolist                   # expect: baseos, appstream, extras, epel, powertools, gh-cli, nodesource*
dnf module list llvm-toolset   # expect: default stream marked [d] (17.0 on 8.10)
```

### Verifying PKG-01 (every package resolved) — the decisive build-time gate
```bash
# Run each inside the built image; any non-zero exit fails the phase.
pkg-config --version && gcc --version | head -1 && clang --version | head -1 \
  && cmake --version | head -1 && ninja --version && git --version \
  && gh --version && ruby --version && wget --version | head -1 \
  && curl --version | head -1 && jq --version && ld --version | head -1 \
  && pkg-config --exists vulkan && pkg-config --exists gtk+-3.0 \
  && pkg-config --exists libsecret-1 && rpm -q libatomic
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `apt install -y -t bullseye-backports …` | `dnf install -y …` + AppStream module streams + third-party repos | This port | No backports repo on EL8; newer toolchain comes from module streams (`llvm-toolset`, `ruby`) and vendor repos. |
| `Acquire::Check-Valid-Until=false` archive hack | Nothing (base is maintained) | This port | The EOL workaround is deleted entirely — AlmaLinux 8 is supported to May 2029. |
| `dpkg --print-architecture` arch detection | `uname -m` | Phase 2 | EL8 has no dpkg; applies to tarball toolchain layers only. |
| Bullseye clang 11 (predates `-fuse-ld=mold`) | EL8 clang 17+ via module | This port | Clang ≥ 16 supports `-fuse-ld=mold` natively; the mold `update-alternatives` shim is still kept for link parity (Phase 2). |

**Deprecated/outdated:**
- STACK.md's `ninja-build` → AppStream (MEDIUM) claim — superseded: PowerTools/CRB (verified).
- STACK.md/FEATURES.md's "Vulkan requires EPEL" hypothesis — superseded: AppStream (verified).

## Build-Time Validation Checklist (risks & unknowns the planner must encode as verification steps)

Every item below **cannot** be resolved from local files or Repology and must be confirmed at `docker build` time:

1. **`libsecret-devel` repo** — STACK (AppStream) vs PITFALLS (BaseOS) conflict. → `dnf info libsecret-devel` inside the build; if it fails, enable the missing repo and retry.
2. **`libcurl-devel` repo** — expected PowerTools/CRB. → `dnf info libcurl-devel`; confirm `powertools` provides it.
3. **`vulkan-loader-devel` repo** — assumed AppStream alongside the loader (loader runtime + headers are VERIFIED AppStream). → `dnf info vulkan-loader-devel`.
4. **`powertools` repo id** — expected `powertools` on AlmaLinux 8. → `dnf repolist`; fall back to writing `almalinux-powertools.repo` if the id differs.
5. **`llvm-toolset` default stream** — expected 17.0.6 on 8.10. → `dnf module list llvm-toolset`; pin an explicit stream for reproducibility if the default drifts.
6. **`ruby` stream** — default 2.5 vs available 3.0/3.1/3.3; bullseye is 2.7 (no exact EL8 match). → ✅ RESOLVED: pin `ruby:3.1` (`dnf module enable ruby:3.1 -y` before the install layer). Assert at build time with `ruby --version` (expect 3.1.x).
7. **`epel-release` strict necessity** — research says optional for this package set, but BASE-02 lists it. → keep it (harmless, satisfies BASE-02); if a package unexpectedly resolves only from EPEL, record that in a comment.
8. **`gnome-keyring` + `vulkan-headers` aarch64 availability** — Repology confirms x86_64; aarch64 is exercised in Phase 4, but the amd64 build is the Phase 1 gate. → note that Phase 4 must re-verify on arm64.
9. **Image size** — after `dnf clean all`, confirm the image is comparable to `debian-bullseye` (success criterion 4). → `docker images` size check.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `vulkan-loader-devel` is in AppStream alongside `vulkan-loader` (only the runtime loader + headers were individually verified) | Package mapping | `No match` at build → enable CRB/EPEL for `-devel`. Low impact, cheap fix. |
| A2 | `libcurl-devel` is in PowerTools/CRB (STACK + PITFALLS consensus; ARCHITECTURE says BaseOS) | Package mapping | If actually BaseOS, the `powertools` enablement step is still needed for `ninja-build`, so no recipe change — only the `dnf info` expectation. Low impact. |
| A3 | `llvm-toolset` default stream is 17.0.6 on 8.10 | Recipe | If the default drifts, `clang` may be a different 17+ version — behaviorally fine (any 17+), but pin for reproducibility. Low-Medium impact. |
| A4 | `openssl-devel` and `chkconfig` should be included in Phase 1 (from STACK.md) even though PKG-01's literal text omits them | Package mapping | `chkconfig` missing ⇒ Phase 2 mold `update-alternatives` fails; `openssl-devel` missing ⇒ later Rust/TLS native builds fail. Medium impact — include both. |
| A5 | NodeSource repo enablement belongs in Phase 1 (BASE-02) with `nodejs` install deferred to Phase 2 | Recipe | If the planner prefers to defer both to Phase 2, BASE-02's literal order is violated — confirm with user. Low impact either way. |

## Open Questions

> **Resolution note (2026-09-08):** All three open questions are RESOLVED and locked in the plan (`01-02-PLAN.md`). Phase 1 proceeds with the resolved choices below; Phase 3 (parity) may revisit the Ruby stream against real builds.

1. **Which `ruby` module stream to pin?** — ✅ RESOLVED: pin `ruby:3.1`.
   - What we know: bullseye ships Ruby 2.7; EL8 has default 2.5 with 3.0/3.1/3.3 available (2.7 has no EL8 stream). Ruby 2.5/2.7 are EOL.
   - What's unclear: whether the consuming builds depend on 2.7 semantics, or any modern 3.x works.
   - **Decision:** do **not** accept the silent default 2.5 (EOL, oldest). Pin `ruby:3.1` explicitly in Phase 1 via `dnf module enable ruby:3.1 -y` BEFORE the install layer; Phase 3 (parity) confirms the choice against real builds.

2. **Should `epel-release` stay in the recipe given research says it's optional?** — ✅ RESOLVED: keep `epel-release`.
   - What we know: BASE-02 and the phase scope list it; research shows Vulkan is AppStream so EPEL is not strictly needed.
   - **Decision:** keep it (satisfies BASE-02 literally, harmless, documented fallback); install all packages from native repos without `--enablerepo=epel`.

3. **`dbus-x11` (`dbus-launch`) — needed?** — ✅ RESOLVED: skip `dbus-x11`.
   - What we know: bullseye's `dbus` package provides `dbus-launch`; on EL8 it's a separate `dbus-x11` package. PITFALLS says only add if `dbus-launch` is actually used.
   - **Decision:** install `dbus dbus-daemon dbus-tools` only; add `dbus-x11` later only if a Phase 3 keyring smoke test requires `dbus-launch`.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Docker CLI | `docker build` | ✓ | 28.0.4 | — |
| Docker buildx | multi-arch (Phase 4) | ✓ | v0.22.0 | — |
| Docker daemon (Docker Desktop engine) | `docker build` for Phase 1 verification | ✗ **not running** | — | Start Docker Desktop before executing/verifying Phase 1 |
| Network → repo.almalinux.org, cli.github.com, rpm.nodesource.com | dnf install / repo enablement | ⚠️ not probed | — | Required at build time; standard public egress assumed |

**Missing dependencies with no fallback:**
- Docker daemon must be running to satisfy Phase 1 success criteria (build + `ldd --version`). Start Docker Desktop prior to execution.

**Missing dependencies with fallback:**
- None — the phase's other "dependencies" are network endpoints reached from inside the build.

## Security Domain

> `security_enforcement: true` (ASVS level 1). This phase is a **CI build image**, not a web application; most ASVS web-app categories are not applicable. The applicable surface is **software supply chain**.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | N/A — no app-level auth |
| V3 Session Management | no | N/A |
| V4 Access Control | no | N/A |
| V5 Input Validation | no | N/A — no user input surface |
| V6 Cryptography | partial | Use distro `ca-certificates`/`openssl-libs` for TLS; never hand-roll crypto. |

### Known Threat Patterns for an RPM-based CI image

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Tampered third-party repo package (gh, NodeSource) | Tampering | `gpgcheck=1` on all repos; official repo files + keys; no `--nogpgcheck`. |
| Unpinned/floating package versions | Tampering | Pin toolchain versions (Phase 2); for distro packages rely on the rolling `:8` tag's security updates. |
| Unauthenticated script execution (NodeSource `setup_24.x`) | Spoofing/Tampering | `curl -fsSL` over TLS; review before promotion; delete script after use. |
| Base image from unofficial mirror | Spoofing | Official `almalinux:8` Docker Official Image only. |
| Excessive attack surface | Elevation of privilege | Install only the parity package set; no X server, desktop, docs, or "convenience" extras. |

## Sources

### Primary (HIGH confidence — verified this session)
- Repology — `ninja` (AlmaLinux 8 PowerTools, ninja-build 1.8.2), `vulkan-headers` + `vulkan-loader` (AlmaLinux 8 AppStream, 1.3.283.0), `gnome-keyring` (AlmaLinux 8 AppStream, 3.28.2), `libsecret` (AlmaLinux 8 BaseOS, 0.18.6), `curl` (AlmaLinux 8 BaseOS, 7.61.1) — https://repology.org/
- `W:\gnus\CIDocker\debian-bullseye\Dockerfile` — authoritative parity source of truth (package inventory, env contract).

### Secondary (MEDIUM confidence — prior-session verification, cross-referenced)
- `research/STACK.md` — ordered recipe, Debian→EL8 mapping, module/repo notes.
- `research/PITFALLS.md` — repo placements (ninja/libcurl/clang module), dbus sub-packages, GPG, cache cleanup; glibc floors for JDK/Node/Rust.
- `research/ARCHITECTURE.md` — layer structure, EPEL-not-required correction, `powertools` id.
- `research/FEATURES.md` + `research/SUMMARY.md` — feature inventory, conflict flags, phase ordering.
- `research/REQUIREMENTS.md`, `research/ROADMAP.md`, `research/PROJECT.md`, `research/STATE.md` — phase scope, success criteria, constraints.

### Tertiary (LOW confidence — flagged for build-time validation)
- `libsecret-devel` repo (AppStream vs BaseOS conflict across STACK/PITFALLS).
- `vulkan-loader-devel` sub-package repo (assumed alongside loader).
- `ruby` module stream choice (no EL8 2.7 equivalent; nearest streams 3.0/3.1/3.3).
- `llvm-toolset` default stream stability on the rolling `:8` tag.

## Metadata

**Confidence breakdown:**
- Standard stack (package mapping): HIGH for base/repo shape and 9 of the placements (Repology-verified); MEDIUM for `libcurl-devel`/`libsecret-devel`/`vulkan-loader-devel`/ruby-stream.
- Architecture: HIGH — mirrors the existing `debian-bullseye` convention and STACK/ARCHITECTURE research.
- Pitfalls: HIGH — repo-placement pitfalls verified via Repology; dbus/GPG/cache pitfalls from PITFALLS.md (prior-session verified).

**Research date:** 2026-09-08
**Valid until:** 2026-09-22 (stable distro; re-verify only if the AlmaLinux 8 package indexes change or a new 8.x minor ships)
