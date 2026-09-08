# Architecture Research: AlmaLinux 8 CI Build Image

**Domain:** CI build-image repository (Dockerfiles carrying Rust/Node/JDK/mold/GTK/Vulkan toolchain)
**Researched:** 2026-09-08
**Confidence:** HIGH

## Standard Architecture

### System Overview

The repo is a *collection of self-contained base images*, one directory per distro.
Each image is a single `Dockerfile` built bottom-up as a stack of layers, where the
top layers hold the most frequently changed toolchain components.

```
┌──────────────────────────────────────────────────────────────────┐
│                        almalinux-8/Dockerfile                    │
├──────────────────────────────────────────────────────────────────┤
│  Layer 7  FINAL: git safe.directory + dbus machine-id            │
├──────────────────────────────────────────────────────────────────┤
│  Layer 6  ENV  JAVA_HOME / JAVA_* / JDK_HOME / PATH              │
├──────────────────────────────────────────────────────────────────┤
│  Layer 5  RUN  Temurin JDK 25 (Adoptium tarball, arch-mapped)    │
├──────────────────────────────────────────────────────────────────┤
│  Layer 4  RUN  Rust 1.87.0 (rustup-init, SHA256-pinned)          │
├──────────────────────────────────────────────────────────────────┤
│  Layer 3  RUN  mold (static binary) + Node 24 (NodeSource)       │
├──────────────────────────────────────────────────────────────────┤
│  Layer 2  RUN  dnf install (all EL8 packages, single layer)      │
├──────────────────────────────────────────────────────────────────┤
│  Layer 1  RUN  repo enablement (dnf-plugins-core + gh repo)      │
├──────────────────────────────────────────────────────────────────┤
│  Layer 0  ENV  RUSTUP_HOME / CARGO_HOME / PATH / RUST_VERSION    │
├──────────────────────────────────────────────────────────────────┤
│  FROM almalinux:8        (multi-arch manifest: amd64 + arm64)    │
└──────────────────────────────────────────────────────────────────┘
```

### Component Responsibilities

| Component | Responsibility | Implementation |
|-----------|----------------|----------------|
| `FROM almalinux:8` | Base OS + glibc 2.28 | Docker Official Image, multi-arch manifest |
| Repo enablement | Add non-default package sources | `dnf-plugins-core` → `dnf config-manager` |
| dnf install layer | All distro packages at once | single `RUN dnf install -y ...` |
| mold | Fast linker (LLVM-compatible) | upstream static tarball + `update-alternatives` |
| node | Node.js 24 runtime | NodeSource `setup_24.x` script |
| rust | Rust toolchain 1.87.0 | rustup-init, SHA256-pinned per arch |
| jdk | Temurin JDK 25 | Adoptium tarball, distro-agnostic |
| ENV layer | JVM + Cargo path contract | `/etc/profile.d` + Dockerfile `ENV` |

## Recommended Project Structure

```
W:\gnus\CIDocker\
├── README.md                  # unchanged (one-liner, keep)
├── .planning\                 # GSD artifacts (ignored by image builds)
├── debian-bullseye\
│   └── Dockerfile             # existing image (keep, grace period)
└── almalinux-8\               # NEW — mirrors debian-bullseye convention
    └── Dockerfile             # the port; single file, same heredoc style
```

### Structure Rationale

- **`almalinux-8/` directory name:** lowercase distro + hyphenated major version,
  exactly matching `debian-bullseye/`. No trailing `.10`, no `_`, no `-image`
  suffix — the directory *is* the image identity, and CI keys off the directory name.
- **Single `Dockerfile` per directory:** no `docker-compose`, no `Makefile`, no
  `.dockerignore` — none exist for `debian-bullseye/`, so none are added here.
  Build orchestration (buildx) lives in CI, not in the repo.
- **No shared base image or multi-stage from a common parent:** each distro is
  fully self-contained (a deliberate choice in the existing repo). Do not
  introduce a shared `base/` directory now; it would break the "drop-in
  alternative" relationship between the two images.

## Architectural Patterns

### Pattern 1: One Package-Manager Layer for All Distro Packages

**What:** Every distro-provided package is installed in a single `RUN dnf install -y ...`
block, mirroring the bullseye image's single `apt install` block.

**When to use:** Always, for this image type. The toolchain components (mold,
node, rust, jdk) are installed from upstream binaries in their own layers.

**Trade-offs:** A single large layer means any one package change invalidates the
whole layer — but these packages change rarely, and a single layer avoids
partial-install states and maximizes layer-cache hits across CI runs.

**RHEL 8 specifics that must be respected:**
- Run `dnf install -y dnf-plugins-core` **before** any `dnf config-manager` call.
- `pkg-config` is provided by `pkgconf-pkg-config` on EL8 (not `pkg-config`).
- Package-name translations vs. bullseye:

| bullseye package | AlmaLinux 8 package(s) | Source |
|------------------|------------------------|--------|
| `libcurl4-openssl-dev` | `libcurl-devel` | BaseOS |
| `libsecret-1-dev` | `libsecret-devel` | AppStream |
| `libvulkan-dev` | `vulkan-headers` + `vulkan-loader` | **AppStream** |
| `libgtk-3-dev` | `gtk3-devel` | AppStream |
| `ruby-full` | `ruby` + `ruby-devel` | AppStream |
| `libatomic1` | `libatomic` | BaseOS |
| `pkg-config` | `pkgconf-pkg-config` | BaseOS |
| `gh` | `gh` | GitHub CLI repo (external) |
| `sudo`, `git`, `clang`, `cmake`, `wget`, `curl`, `dbus`, `gnome-keyring`, `ninja-build`, `jq` | same names | BaseOS/AppStream |

### Pattern 2: Repo Enablement Precedes Install (Layer 1 → Layer 2)

**What:** Non-default package sources are enabled in a dedicated layer before the
install layer.

**When to use:** When a package (`gh`) is not in base EL repos.

**Trade-offs:** One extra cached layer, but it isolates the "mutate repo config"
side effect from package installation and lets the install layer stay a pure
`dnf install`.

**Verified commands (AlmaLinux 8):**
```bash
# Layer 1 — non-default sources
RUN dnf install -y dnf-plugins-core && \
    dnf config-manager --add-repo https://cli.github.com/packages/rpm/gh-cli.repo
```

**Correction to the project hypothesis:** `vulkan-headers` and `vulkan-loader`
are in **AlmaLinux 8 AppStream**, not EPEL (confirmed across AlmaLinux, Rocky,
CentOS 8 AppStream). **EPEL is therefore NOT required** for the current package
set. Keep these as a *conditional fallback* only if `dnf install` resolution fails:

```bash
# Fallback only — do not run by default
dnf install -y epel-release
dnf config-manager --set-enabled powertools   # CRB equivalent on AlmaLinux 8
```

`powertools` (AlmaLinux's name for CodeReady Builder) is the repo most EPEL
packages build-depend on; enable it in the same fallback block if EPEL is ever
introduced. There is no "epel-release before vulkan" ordering constraint because
Vulkan is already in AppStream.

### Pattern 3: Architecture-Dependent Install Layers Use `uname -m` + Reduced Case Maps

**What:** Each arch-sensitive layer (mold, rust, jdk) detects the target arch and
downloads the matching upstream binary.

**When to use:** For every toolchain component fetched as an upstream tarball.

**Trade-offs:** Explicit arch maps are verbose but self-documenting and fail
loudly (`exit 1`) on unknown arches. EL8 has no `dpkg`, so use `uname -m`
(returns `x86_64` / `aarch64` directly) instead of `dpkg --print-architecture`.

**The mandatory change:** the bullseye `case` statements carry `armhf` and
`i386` branches. RHEL 8 clones ship neither, and Temurin JDK 25 already excludes
them. **Drop both branches everywhere** and fail on any arch other than
`x86_64`/`aarch64`.

```bash
# mold — arch map (amd64 + arm64 only)
case "$(uname -m)" in
    x86_64)  moldArch='x86_64'  ;;
    aarch64) moldArch='aarch64' ;;
    *) echo >&2 "unsupported architecture for mold: $(uname -m)"; exit 1 ;;
esac

# rust — arch map (amd64 + arm64 only)
case "$(uname -m)" in
    x86_64)  rustArch='x86_64-unknown-linux-gnu';  rustupSha256='20a06e644b0d9bd2fbdbfd52d42540bdde820ea7df86e92e533c073da0cdd43c' ;;
    aarch64) rustArch='aarch64-unknown-linux-gnu'; rustupSha256='e3853c5a252fca15252d07cb23a1bdd9377a8c6f3efa01531109281ae47f841c' ;;
    *) echo >&2 "unsupported architecture: $(uname -m)"; exit 1 ;;
esac

# jdk — arch map (amd64 + arm64 only)
case "$(uname -m)" in
    x86_64)  jdkArch='x64';     javaDir='amd64' ;;
    aarch64) jdkArch='aarch64'; javaDir='arm64' ;;
    *) echo >&2 "unsupported architecture: $(uname -m)"; exit 1 ;;
esac
```

**mold + clang note:** EL8 AppStream ships clang 16+, which supports
`-fuse-ld=mold` natively (bullseye's clang 11 did not). Keep the
`update-alternatives --install /usr/bin/ld ld /usr/local/bin/ld.mold 100`
registration anyway: it preserves byte-for-byte link parity with the bullseye
image for builds that never pass `-fuse-ld=mold`.

## Data Flow

### Build-time data flow (per target arch)

```
docker buildx build --platform linux/amd64,linux/arm64
        │
        ▼
FROM almalinux:8  ──(multi-arch manifest resolves per platform)──▶ base fs
        │
        ▼
Layer 1: add gh repo (dnf-plugins-core)
        ▼
Layer 2: dnf install packages ──(single transaction)──▶ /usr, /usr/lib, /etc
        ▼
Layer 3: mold tarball ──▶ /usr/local/bin/ld.mold;  node script ──▶ nodejs
        ▼
Layer 4: rustup-init ──▶ /usr/local/rustup + /usr/local/cargo
        ▼
Layer 5: jdk tarball ──▶ /usr/lib/jvm/temurin-25-jdk
        ▼
Layer 6/7: ENV + runtime glue (safe.directory, dbus machine-id)
```

### Key data flows

1. **Toolchain pinning:** `RUST_VERSION=1.87.0` and the JDK release tag are
   constants at the top of the file, consumed by layers 4 and 5 — keep the
   version pins in ENV/comments where the bullseye file keeps them.
2. **JVM discovery:** Layer 5 writes `/etc/profile.d/java-env.sh`; layer 6 sets
   the Dockerfile `ENV` for non-login shells. Both are required (mirror bullseye).
3. **Registry output:** multi-arch manifests are assembled by buildx at push
   time; nothing in the Dockerfile changes between arches.

## Scaling Considerations

| Scale | Architecture Adjustments |
|-------|--------------------------|
| 1 image / 2 arches | Single Dockerfile, `--platform linux/amd64,linux/arm64` — no changes needed |
| + more distros | Add another sibling directory (e.g. `almalinux-9/`), no shared base |
| Many CI runners | Push once to a registry; runners `docker pull` the manifest for their arch |

### Scaling Priorities

1. **First bottleneck:** cross-arch emulation. Building `arm64` on an `amd64`
   builder requires QEMU `binfmt_misc` registration (`docker/setup-qemu-action`
   in CI, or `docker run --privileged --rm tonistiigi/binfmt --install all`).
   Without it, `--platform linux/arm64` RUN steps fail with "exec format error".
2. **Second bottleneck:** registry auth on multi-arch push. Use
   `--push` (buildx assembles the manifest) rather than building per-arch and
   pushing separate tags.

## Anti-Patterns

### Anti-Pattern 1: Copying the bullseye apt/backports layer verbatim

**What people do:** Paste the bullseye Dockerfile and swap `apt` → `dnf`
mechanically, keeping the `bullseye-backports` source and `dpkg` calls.

**Why it's wrong:** EL8 has no `dpkg`, no backports repo, and different package
names (`libcurl-devel`, `libsecret-devel`, `pkgconf-pkg-config`).

**Do this instead:** Use `uname -m` for arch detection and the package-name table
above; add `dnf clean all` at the end of the install layer to keep the image lean.

### Anti-Pattern 2: Keeping armhf/i386 in the arch case statements

**What people do:** Leave the 4-way `case` blocks from bullseye untouched.

**Why it's wrong:** RHEL 8 clones ship no 32-bit images; the branches are dead
code that will never execute and imply support that does not exist.

**Do this instead:** Two-arm maps (`x86_64`/`aarch64`) with a hard `exit 1` default.

### Anti-Pattern 3: Adding EPEL unconditionally

**What people do:** Install `epel-release` preemptively because "Vulkan needs it."

**Why it's wrong:** On AlmaLinux 8, Vulkan is in AppStream. EPEL adds a
third-party repo surface and can shadow base packages.

**Do this instead:** Install EPEL + enable `powertools` only if `dnf install`
fails to resolve a required package — and record why in a comment.

## Integration Points

### External Services

| Service | Integration Pattern | Notes |
|---------|---------------------|-------|
| Docker Hub `almalinux` | `FROM almalinux:8` | `8`/`8.10` are multi-arch (amd64, arm64/v8, ppc64le, s390x); buildx `--platform` restricts to our two |
| GitHub CLI repo | `dnf config-manager --add-repo https://cli.github.com/packages/rpm/gh-cli.repo` | DNF4 path (EL8 ships dnf4, not dnf5) |
| NodeSource | `curl -fsSL https://rpm.nodesource.com/setup_24.x \| bash -` then `dnf install -y nodejs` | RHEL 8 is supported; x86_64 + arm64 only |
| Adoptium | `https://github.com/adoptium/temurin25-binaries/releases/...` tarball | distro-agnostic; `x64`/`aarch64` names |
| rust-lang static | `https://static.rust-lang.org/rustup/archive/1.28.2/...` | SHA256 pinned per arch |
| mold releases | `https://github.com/rui314/mold/releases/download/v2.42.0/...` | `x86_64`/`aarch64` tarball names |

### Internal Boundaries

| Boundary | Communication | Notes |
|----------|---------------|-------|
| `debian-bullseye/` ↔ `almalinux-8/` | None (fully independent) | Both images coexist during the grace period; no shared layers |
| Layers 3–5 ↔ Layer 2 | Filesystem (`curl`, `wget`, `tar`, `sha256sum`) | Layers 3–5 depend on tools installed in Layer 2 |
| CI ↔ repo | Directory name = image identity | CI selects Dockerfile by directory |

## Multi-Arch Build Approach (concrete)

```bash
# one-time builder setup (CI: use docker/setup-qemu-action for arm64 emulation)
docker buildx create --name cibuilder --use || docker buildx use cibuilder
docker run --privileged --rm tonistiigi/binfmt --install all   # only if cross-arch

# build + push the multi-arch manifest
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t <registry>/almalinux-8:<tag> \
  --push .
```

- **`--platform linux/amd64,linux/arm64`** — buildx emits one manifest with both
  digests; `--push` is required for a multi-arch result (a plain `--load` only
  supports a single platform).
- **Local single-arch smoke test** (e.g. Apple Silicon host): build with
  `--platform linux/arm64 --load` and `docker run` it.
- **Arch detection inside the build:** all arch-specific downloads use `uname -m`
  and the reduced 2-arm case maps (see Pattern 3); no build-time `ARG TARGETARCH`
  is required because each layer already self-detects via `uname -m`.
- **What changes from bullseye:** `dpkg --print-architecture` → `uname -m`;
  `amd64`/`arm64` labels → `x86_64`/`aarch64`; `armhf`/`i386` branches deleted;
  node script host → `rpm.nodesource.com`.

## Sources

- AlmaLinux Docker Official Image (tags `8`, `8.10` multi-arch: amd64 + arm64/v8):
  https://hub.docker.com/_/almalinux/tags — HIGH
- AlmaLinux wiki, EPEL & CRB/PowerTools enablement:
  https://wiki.almalinux.org/repos/Extras.html — HIGH
- Repology — `vulkan-headers` and `vulkan-loader` in AlmaLinux 8 AppStream:
  https://repology.org/project/vulkan-headers/versions
  https://repology.org/project/vulkan-loader/versions — HIGH
- GitHub CLI official Linux install (RPM / DNF4):
  https://github.com/cli/cli/blob/trunk/docs/install_linux.md — HIGH
- NodeSource distributions — RHEL 8 supported, x86_64 + arm64 only:
  https://github.com/nodesource/distributions/blob/master/DEV_README.md — HIGH
- Existing reference image:
  `W:\gnus\CIDocker\debian-bullseye\Dockerfile` — HIGH (source of truth for parity)
- `W:\gnus\CIDocker\.planning\PROJECT.md` — HIGH (constraints & decisions)

---
*Architecture research for: AlmaLinux 8 CI build image*
*Researched: 2026-09-08*
