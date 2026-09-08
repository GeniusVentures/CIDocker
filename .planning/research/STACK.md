# Stack Research

**Domain:** AlmaLinux 8 CI build image (RHEL 8 rebuild) reproducing the `debian-bullseye` toolchain
**Researched:** 2026-09-08
**Confidence:** HIGH (stack shape); MEDIUM on a handful of per-package repo placements — flagged inline

## Recommended Stack

### Core Technologies

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| `almalinux:8` (Docker Official Image) | rolling latest 8.x (currently 8.10) | Base image | Official, maintained by AlmaLinux; `:8` auto-updates the base layer with security fixes and publishes **amd64 + arm64** multi-arch manifests. RHEL-clone glibc 2.28 satisfies the binary-compat constraint (older than bullseye's 2.31). |
| `dnf` + `dnf-plugins-core` | — | Package manager | Replaces `apt`. `dnf config-manager` (for repo enablement) lives in `dnf-plugins-core` and is **not** guaranteed present in the minimal image — install it first. |
| EPEL (`epel-release`) | — | Extra packages | Third-party ecosystem repo; `dnf install epel-release` is pulled from the `extras` repo which the AlmaLinux image ships enabled. Needed as a fallback source for some Vulkan/devel packages and community tools. |
| PowerTools (CRB on 9) | — | `-devel` packages | On **AlmaLinux 8 the repo id is `powertools`** (`crb` on 9). Source of `libcurl-devel`, `vulkan-headers`, and other dev headers that RHEL removes from AppStream/BaseOS. |
| GitHub CLI repo | — | `gh` | `gh` is **not** in base/EPEL repos. Add `https://cli.github.com/packages/rpm/gh-cli.repo` (official rpm repo, works on RHEL/CentOS 8). |
| NodeSource `setup_24.x` | Node 24.x | Node runtime | Same script the bullseye image uses; the rpm build (`rpm.nodesource.com`) supports **x86_64 + arm64** and Redhat 8, so the switch from `deb.nodesource.com` to `rpm.nodesource.com` is the only change. |

### Package Mapping — Debian → EL8 (dnf)

Every package from the existing `debian-bullseye/Dockerfile`, with the exact EL8 equivalent and its repo.

| Debian package (existing) | EL8 dnf package | Repo | Confidence | Notes |
|---------------------------|-----------------|------|------------|-------|
| `sudo` | `sudo` | BaseOS | HIGH | Same name. |
| `pkg-config` | `pkgconf-pkg-config` | AppStream | HIGH | EL8 has no `pkg-config` package; `pkgconf-pkg-config` provides `/usr/bin/pkg-config` and the `pkgconfig` virtual. |
| `git` | `git` | AppStream | HIGH | 2.43.x on 8.10. |
| `ruby-full` | `ruby` + `ruby-devel` | AppStream (module) | MEDIUM | No `ruby-full` on EL8. `ruby` (module; 2.5 default stream, 3.1 available) bundles rubygems + core stdlib gems; add `ruby-devel` for the C-extension headers `ruby-full` implies. |
| `clang` | `clang` | AppStream (llvm-toolset module) | HIGH | Default stream is **17.0.6** on 8.10 (18/19/20/21 streams also present). Pulls `clang-libs`, `llvm`, `libomp` transitively. |
| `cmake` | `cmake` | AppStream | HIGH | 3.26.5 on 8.10. |
| `gh` | `gh` | **GitHub CLI repo** | HIGH | Not in base/EPEL. See repo step. |
| `wget` | `wget` | BaseOS | HIGH | Not in the minimal image by default — install explicitly. |
| `curl` | `curl` | BaseOS | HIGH | Minimal image ships only `curl-minimal` (if any); install full `curl`. |
| `libcurl4-openssl-dev` | `libcurl-devel` | **PowerTools/CRB** | HIGH | Runtime `libcurl` is BaseOS; the dev package is in CRB on EL8 (this is the canonical name change). |
| `libsecret-1-dev` | `libsecret-devel` | AppStream | MEDIUM | Runtime `libsecret` is BaseOS; `libsecret-devel` resolves once AppStream+CRB are enabled. |
| `dbus` | `dbus` | BaseOS | HIGH | `dbus-libs` comes transitively. (`dbus-devel` is AppStream if ever needed.) |
| `gnome-keyring` | `gnome-keyring` | AppStream | MEDIUM | Present in AppStream; validate aarch64 build in the port phase. |
| `ninja-build` | `ninja-build` | AppStream | MEDIUM | In AppStream on EL8 (was EPEL-only on EL7). |
| `libvulkan-dev` | `vulkan-loader` + `vulkan-loader-devel` + `vulkan-headers` | AppStream (`vulkan-loader`) + CRB (`-devel`, `vulkan-headers`) | MEDIUM | EL8 splits Vulkan across repos: loader runtime in AppStream, headers/dev-symlink (`libvulkan.so`) in CRB. If `vulkan-headers` is absent from CRB on your build host, EPEL provides it. **Flag for validation.** |
| `libgtk-3-dev` | `gtk3-devel` | AppStream | HIGH | Pulls `atk-devel`, `pango-devel`, `cairo-devel`, `gdk-pixbuf2-devel`, `glib2-devel` transitively (all AppStream). Runtime `gtk3` is AppStream. |
| `jq` | `jq` | AppStream | HIGH | (`jq-devel` is CRB; not needed.) |
| `libatomic1` | `libatomic` | BaseOS | MEDIUM | gcc runtime lib; resolves once BaseOS/AppStream enabled. |

### Additional `-devel` / build packages EL8 requires

Debian images implicitly ship a working C/C++ build env (build-essential via many deps). EL8 does **not** — `clang` on its own does not pull a linker, `make`, or libc headers. Add these explicitly so `cmake`/`cargo`/`clang` can actually compile:

| Package | Repo | Why |
|---------|------|-----|
| `gcc` + `gcc-c++` | AppStream | Provides `cc`/`c++`, `glibc-devel`, `glibc-headers`, `libstdc++-devel` (headers every native build needs). |
| `make` | BaseOS | `cmake` and `cargo` build scripts invoke `make`. |
| `binutils` | BaseOS | `ld`, `as`, `ar`, `nm` — required even when clang is the compiler. |
| `openssl-devel` | BaseOS/AppStream (MEDIUM) | Rust crates using `openssl-sys` and CMake TLS deps link against it; bullseye pulled it via `libcurl4-openssl-dev`. |
| `chkconfig` | BaseOS | Provides `/usr/sbin/update-alternatives` on EL8 — needed to register mold as the default `ld` (parity with the bullseye image). |

### Development Tools (carry-over assessment)

| Tool | Carry over unchanged? | Notes |
|------|----------------------|-------|
| **mold 2.42.0** (upstream static tarball) | ✅ YES | Distro-agnostic static build, works on glibc 2.28. Keep the exact `wget`+`tar`+`update-alternatives --install /usr/bin/ld ld /usr/local/bin/ld.mold 100` recipe — `update-alternatives` exists on EL8 once `chkconfig` is installed. EL8 clang 17 supports `-fuse-ld=mold` natively, so the shim is now optional-but-harmless; keep it for byte-for-byte parity of link commands. |
| **rustup 1.28.2** → Rust 1.87.0 | ✅ YES | Same tarball URLs + SHA256 pins. **Drop the `armhf` and `i386` branches** (RHEL clones ship neither) — keep `amd64` (`x86_64-unknown-linux-gnu`) and `arm64` (`aarch64-unknown-linux-gnu`). Requires `wget` + `sha256sum` (coreutils) only. |
| **Temurin JDK 25.0.2+10** | ✅ YES | Adoptium tarball is distro-agnostic. Keep `amd64` (`x64`) + `arm64` (`aarch64`) branches; both `armhf`/`i386` branches already error out — remove them. Symlink + `profile.d` setup unchanged (no `update-alternatives` needed for java). |
| **Node 24** | ⚠️ script URL changes | Same `setup_24.x` mechanism, but `https://rpm.nodesource.com/setup_24.x` (not `deb.nodesource.com`). Script writes an `el/8` repo; then `dnf install -y nodejs`. No `sudo` wrapper needed (container runs as root). |

## Installation (ordered dnf recipe)

```dockerfile
# syntax=docker/dockerfile:1
FROM almalinux:8

ENV RUSTUP_HOME=/usr/local/rustup \
    CARGO_HOME=/usr/local/cargo \
    PATH=/usr/local/cargo/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
    RUST_VERSION=1.87.0

# 1) Bootstrap package manager tooling + base utilities (idempotent, ordered)
RUN dnf install -y \
        dnf-plugins-core \
        wget curl tar gzip xz ca-certificates \
        chkconfig

# 2) Enable EPEL (from Extras, already enabled in the image)
RUN dnf install -y epel-release

# 3) Enable PowerTools (CRB) for -devel packages
RUN dnf config-manager --set-enabled powertools

# 4) GitHub CLI official rpm repo
RUN dnf config-manager --add-repo https://cli.github.com/packages/rpm/gh-cli.repo

# 5) NodeSource 24.x (rpm build; needs curl from step 1)
RUN curl -fsSL https://rpm.nodesource.com/setup_24.x -o /tmp/nodesource_setup.sh \
    && bash /tmp/nodesource_setup.sh \
    && rm /tmp/nodesource_setup.sh

# 6) Toolchain (parity with debian-bullseye apt list + EL8 build essentials)
RUN dnf install -y \
        sudo \
        pkgconf-pkg-config \
        git \
        ruby ruby-devel \
        clang \
        cmake \
        make gcc gcc-c++ binutils \
        gh \
        nodejs \
        openssl-devel \
        libcurl-devel \
        libsecret-devel \
        dbus \
        gnome-keyring \
        ninja-build \
        vulkan-loader vulkan-loader-devel vulkan-headers \
        gtk3-devel \
        jq \
        libatomic
```

> If step 3 reports "Unknown repo 'powertools'", the container's repo file names it differently — add `/etc/yum.repos.d/almalinux-powertools.repo` pointing at `https://repo.almalinux.org/almalinux/8/PowerTools/$basearch/os/` (mirror the `almalinux.repo` structure, `enabled=1`) and retry.

Follow steps 1–6 with the **unchanged** mold / rustup / Temurin heredocs from the existing Dockerfile (minus the dropped 32-bit architecture branches), then the `git config --system --add safe.directory '*'` and the dbus `machine-id` setup.

## Alternatives Considered

| Recommended | Alternative | When to Use Alternative |
|-------------|-------------|-------------------------|
| `almalinux:8` (rolling) | `almalinux:8.10` (pinned minor) | Pin `8.10` only if you want the base-layer packages (glibc etc.) frozen for reproducibility. Note dnf repos still point at rolling `8`, so a pinned base does **not** freeze anything installed via dnf. |
| AlmaLinux 8 | Rocky Linux 8 | Rocky is equivalent (same RHEL 8 lineage). Alma chosen (per PROJECT.md decision); swap is drop-in. |
| `powertools` + EPEL for Vulkan/devel | Build Vulkan headers from source | Never for a CI image — adds fragility. Use CRB/EPEL packages. |
| NodeSource rpm for Node 24 | `dnf module enable nodejs` | Module streams on EL8 only go to Node 20; Node 24 **requires** NodeSource. |
| `gh` from GitHub CLI rpm repo | `gh` binary tarball from releases | Tarball works too, but the rpm repo keeps `gh` updated via dnf — use the repo. |
| upstream mold tarball | `mold` from EPEL | EPEL has **no** mold package on EL8. Upstream tarball is the only path — unchanged from bullseye. |

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| `mold` RPM / EPEL mold | No mold package exists for EL8 | Upstream static tarball (unchanged recipe). |
| Base `gcc` 8.5.0 as the project compiler | Ancient (2019), missing modern C++/OpenMP features; would silently change build behavior vs bullseye's clang | `clang` 17.0.6 is the compiler of record; keep `gcc`/`gcc-c++` **only** for `cc`, libc headers, and `libstdc++`. If a crate demands newer GCC, `gcc-toolset-13` (gcc 13.3.1, AppStream) is the escape hatch — not default. |
| `libvulkan` / `vulkan` package names | Don't exist on EL8 | `vulkan-loader` (+ `-devel`) and `vulkan-headers`. |
| `ruby-full` | Debian-only name | `ruby` + `ruby-devel`. |
| `dnf install pkg-config` | No such package on EL8 | `pkgconf-pkg-config`. |
| `armhf` / `i386` targets | RHEL clones ship neither; Temurin already excludes them | `amd64` + `arm64` only — delete those branches when porting. |
| AlmaLinux 9 (`crb` repo id) | glibc 2.34 violates the ≤2.31 binary-compat constraint | AlmaLinux 8 (`powertools` repo id). |
| `--enablerepo=crb` on 8 | `crb` is the 9/CRB repo id | `--set-enabled powertools` on AlmaLinux 8. |

## Stack Patterns by Variant

**If amd64:**
- Use `x86_64-unknown-linux-gnu` (rustup), `x64` (Temurin), `x86_64` (mold). All verified present in EL8 repos.

**If arm64:**
- Use `aarch64-unknown-linux-gnu` (rustup), `aarch64` (Temurin), `aarch64` (mold). EL8 AppStream ships aarch64 builds for clang/cmake/gtk3/vulkan; NodeSource rpm supports arm64. **Validate `gnome-keyring` + `vulkan-headers` aarch64 availability in the port phase** (MEDIUM confidence on these two).

## Version Compatibility

| Package A | Compatible With | Notes |
|-----------|-----------------|-------|
| Rust 1.87.0 (rustup) | glibc 2.28 | ✅ Prebuilt `x86_64-unknown-linux-gnu` / `aarch64-unknown-linux-gnu` binaries run on glibc 2.28. |
| mold 2.42.0 (static) | glibc 2.28 | ✅ Static; no distro deps. |
| Temurin JDK 25 | glibc 2.28 | ✅ Adoptium builds target older glibc; 25.0.2+10 runs on 2.28. |
| Node 24 (NodeSource) | glibc 2.28 | ✅ Node 24 requires glibc ≥ 2.28 — exactly AlmaLinux 8's floor. Do not downgrade. |
| clang 17.0.6 | mold via `-fuse-ld=mold` | ✅ clang ≥ 12 supports it; bullseye's clang 11 did not (why the image used `update-alternatives`). |
| clang 17.0.6 vs bullseye clang 11 | — | ⚠️ **Behavioral change**: newer clang emits different warnings/optimizations. Build outputs may differ from bullseye. Flag in the port phase's verification. |

## Sources

- Docker Hub `library/almalinux` — official image tags (`:8`, `:8.10`) and multi-arch `amd64`/`arm64` manifests (HIGH).
- AlmaLinux wiki — *Repositories* + *EPEL*: `dnf install epel-release`; PowerTools/CRB enablement, `powertools` repo id on 8 (HIGH).
- GitHub CLI install docs — Linux DNF4: `dnf config-manager --add-repo https://cli.github.com/packages/rpm/gh-cli.repo` (HIGH).
- NodeSource install docs — `rpm.nodesource.com/setup_24.x`; rpm build architectures x86_64 + arm64; Redhat 8 supported (HIGH).
- AlmaLinux 8 AppStream/PowerTools package indexes (repo.almalinux.org) — verified `clang-17.0.6`, `cmake-3.26.5`, `gcc-8.5.0`, `glibc-2.28-251.el8_10`, `jq-devel`/`gtk3-devel-docs` (CRB), `dbus-devel` (AppStream) (HIGH for these; individual Vulkan/`libsecret` repo placements MEDIUM — see flags).
- Existing `W:\gnus\CIDocker\debian-bullseye\Dockerfile` — authoritative source for toolchain parity (mold 2.42.0, rustup 1.28.2, Temurin 25.0.2+10, Node 24) (HIGH).

---
*Stack research for: AlmaLinux 8 CI build image*
*Researched: 2026-09-08*
