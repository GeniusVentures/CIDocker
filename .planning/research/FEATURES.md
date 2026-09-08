# Feature Research

**Domain:** CI build image (AlmaLinux 8) — toolchain parity port of `debian-bullseye`
**Researched:** 2026-09-08
**Confidence:** MEDIUM-HIGH (toolchain inventory is exhaustive from the existing Dockerfile; EL package-name mappings are documented in PROJECT.md and standard, but exact names for Vulkan/EPEL and `gnome-keyring` should be validated at build time)

---

## Feature Landscape

For a CI build image, "features" = the toolchain capabilities the image must expose so that
CI pipelines build SuperGenius and SGProcessingManager identically to the current
`debian-bullseye` image. This is a **parity port**, not a new product: the goal is the same
capability set on a still-supported base, not an expanded feature set.

### Table Stakes (Builds Break Without These)

Every tool installed in `debian-bullseye/Dockerfile`, mapped to its AlmaLinux 8 equivalent.
Missing any of these = builds or tests fail, or artifacts differ from the bullseye image.

| Feature | Debian package (existing) | AlmaLinux 8 package (target) | Why Expected | Complexity | Notes |
|---------|---------------------------|------------------------------|--------------|------------|-------|
| Rust toolchain 1.87.0 | `rustup` (minimal profile, `--default-toolchain 1.87.0`) | same via `rustup` 1.28.2 | Project pins the compiler version; a different Rust changes artifacts | MEDIUM | Per-arch `rustup-init` SHA256 pinning; keep `--profile minimal` and `--default-host ${rustArch}` |
| Node.js 24 | nodesource `setup_24.x` + `nodejs` | nodesource `setup_24.x` + `nodejs` (distro-agnostic) | Build scripts require Node 24 | LOW | Same install script works on EL; keep exact major pinned |
| Temurin JDK 25 | Adoptium tarball `jdk-25.0.2+10` | identical Adoptium tarball | Java build steps require JDK 25; version must match for bytecode parity | MEDIUM | Distro-agnostic; preserve `JAVA_HOME`, `JAVA_INCLUDE_PATH{2}`, `JAVA_AWT_INCLUDE_PATH`, `JAVA_JVM_LIBRARY`, `JDK_HOME` env vars |
| Linker: mold 2.42.0 | upstream static binary + `update-alternatives` shim | upstream static binary (mold 2.42.0) | Builds link with mold; mismatched mold changes link output | MEDIUM | May be installable natively via `-fuse-ld=mold` (see Differentiators); parity requires same mold version |
| clang | `clang` (bullseye = v11) | `clang` (AppStream, ≥17) | C/C++ compilation | MEDIUM | Newer clang is expected; verify it doesn't change codegen vs parity expectations |
| cmake | `cmake` | `cmake` (AppStream) | Build system | LOW | |
| ninja-build | `ninja-build` | `ninja-build` | Parallel build backend | LOW | |
| pkg-config | `pkg-config` | `pkgconfig` / `pkgconf-pkg-config` | `.pc` metadata lookups for native deps | LOW | EL package name differs from Debian |
| git | `git` | `git` | Source checkout | LOW | Also reproduce `git config --system --add safe.directory '*'` |
| gh (GitHub CLI) | `gh` | `gh` via GitHub CLI repo | CI release/PR automation | MEDIUM | NOT in base EL repos — requires the `cli/github` dnf repo |
| wget | `wget` | `wget` | Downloads inside Dockerfile | LOW | |
| curl | `curl` | `curl` | Downloads inside Dockerfile | LOW | |
| ruby | `ruby-full` | `ruby` | Build scripts using Ruby | LOW | |
| libcurl (dev) | `libcurl4-openssl-dev` | `libcurl-devel` | Curl-based linking in native deps | LOW | EL name differs |
| libsecret (dev) | `libsecret-1-dev` | `libsecret-devel` | Credential storage (keyring) APIs | LOW | EL name differs |
| dbus | `dbus` | `dbus` | Runtime bus for keyring/services | MEDIUM | Must reproduce the machine-id setup (`/var/lib/dbus/machine-id` + `/etc/machine-id`) or dbus-dependent steps hang |
| gnome-keyring | `gnome-keyring` | `gnome-keyring` | Secret service for credential lookups | MEDIUM | Verify availability in EL8 AppStream; needs dbus machine-id present |
| Vulkan | `libvulkan-dev` | `vulkan-headers` + `vulkan-loader` (EPEL) | Vulkan graphics build deps | MEDIUM | Split into two packages; requires **EPEL** on EL8 |
| GTK3 (dev) | `libgtk-3-dev` | `gtk3-devel` | GTK UI build deps | MEDIUM | EL name differs; pulls large dependency tree — install only what's needed |
| jq | `jq` | `jq` | JSON processing in CI scripts | LOW | |
| libatomic | `libatomic1` | `libatomic` | 128-bit atomic ops on some targets | LOW | EL name differs |
| sudo | `sudo` | `sudo` | Scripts run elevated commands | LOW | |
| Environment | `RUSTUP_HOME`, `CARGO_HOME`, `PATH`, `RUST_VERSION` | identical | Toolchain discovery for cargo/rustc/java | LOW | Preserve exact env-var layout |
| Multi-arch: amd64 + arm64 | `dpkg --print-architecture` branching | `buildx` multi-platform + arch branching | CI must build both targets | **HIGH** | Requires `docker buildx` multi-arch manifests and per-arch SHA/path branching for rustup, mold, JDK |

### Differentiators (Nice-to-Have — NOT Required)

Opportunities where the new image is naturally better than the old one. These are
optional benefits of the migration, not acceptance criteria. Do **not** gate the port on them.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| No EOL apt workaround | AlmaLinux 8 is maintained until May 2029, so `dnf update` works without `Acquire::Check-Valid-Until=false` | LOW | The migration removes the bullseye archive hack entirely |
| Native `-fuse-ld=mold` | EL8 AppStream clang (≥17) supports `-fuse-ld=mold` directly, unlike bullseye's clang 11 | LOW | Could drop the `update-alternatives` shim — but only if link parity is verified |
| Still-supported security patches | Base image receives updates for the distro's remaining lifetime | LOW | Implicit benefit of the migration |
| Cleaner dnf layer caching | Single `dnf install` layer vs `apt` backports juggling | LOW | Cosmetic; not a requirement |

### Anti-Features (Deliberately Excluded)

Scope exclusions from PROJECT.md, plus port-specific temptations to avoid. Explicitly NOT building.

| Anti-Feature | Why Requested / Tempting | Why Problematic | What To Do Instead |
|--------------|--------------------------|-----------------|--------------------|
| `armhf` / `i386` support | Symmetry with rustup's extra branches in the old Dockerfile | RHEL clones ship neither 32-bit arch; Temurin JDK 25 has no 32-bit Linux binaries; doubles CI matrix for no consumer | Keep `amd64` + `arm64` only; drop the legacy `armhf`/`i386` rustup/JDK branches |
| AlmaLinux 9 (glibc 2.34) | Longer support window (2032 vs 2029) | glibc 2.34 raises the binary-compatibility floor, defeating the point of the port | Stay on AlmaLinux 8 / glibc 2.28 |
| A second or newer glibc | Broad compatibility + newer glibc "best of both" | Side-by-side/upgraded glibc breaks the ≤2.31 compatibility guarantee and risks subtle ABI breakage | Keep the distro's single glibc 2.28 untouched |
| Unneeded packages that bloat the image | "While we're here" convenience tooling | Larger images, larger attack surface, slower pulls in CI | Install only the parity toolchain; skip X server, desktop, docs, man pages, JDK demos/source, texlive, etc. |
| Unpinned "latest" toolchain | Simplifies Dockerfile | Non-reproducible builds; artifacts drift from the pinned bullseye image | Pin Rust 1.87.0, Node 24, JDK 25.0.2+10, mold 2.42.0 with SHAs exactly as the old image does |
| Mixing distro bases (Rocky, mixed layers) | Perceived equivalence | PROJECT.md decision is Alma over Rocky; mixing bases muddies reproducibility | Single base `almalinux:8` throughout |
| Blanket EPEL install | One-line Vulkan install | Pulls huge dependency surface; EPEL is a community repo with lower stability guarantees | Enable EPEL and install only `vulkan-headers` + `vulkan-loader` |
| Removing `debian-bullseye` now | Cleanliness | PROJECT.md calls for a grace period until the new image is verified in CI | Keep both images side-by-side during validation |

---

## Feature Dependencies

```
mold native -fuse-ld=mold ──requires──> clang ≥ 16 (EL8 AppStream)
                                        └──requires──> dnf AppStream repos enabled

Vulkan headers/loader ──requires──> EPEL repository enabled

gh (GitHub CLI) ──requires──> cli/github dnf repository

dbus / gnome-keyring at build+test time ──requires──> machine-id setup
                                                        └──requires──> /var/lib/dbus + /etc/machine-id

multi-arch (amd64+arm64) ──requires──> docker buildx
                                        └──requires──> per-arch SHA/path branching (rustup, mold, JDK)

Node 24 ──requires──> nodesource setup_24.x (distro-agnostic)

Temurin JDK 25 ──requires──> Adoptium tarball (distro-agnostic, no dnf repo)
```

### Dependency Notes

- **mold native `-fuse-ld=mold` requires clang ≥ 16:** bullseye's clang 11 predates mold's `-fuse-ld` integration, forcing the `update-alternatives` shim. EL8 AppStream clang satisfies this natively — but this is a *differentiator*, not required; the static-binary + alternatives approach from the old image still works as a fallback.
- **Vulkan requires EPEL:** RHEL 8 clones don't ship Vulkan loader/headers in base repos. EPEL must be enabled first, and only the two Vulkan packages installed from it.
- **gh requires a third-party repo:** GitHub CLI is not in base EL8 repos; the `cli/github` dnf repo (or equivalent pinned source) is a hard dependency.
- **dbus machine-id setup is a runtime prerequisite:** the old image seeds `/var/lib/dbus/machine-id` and `/etc/machine-id`; without it, dbus/keyring-dependent build or test steps can hang. This must be carried over exactly.

---

## MVP Definition

For a parity port, "MVP" = the complete table-stakes list. There is no reduced launch set:
a CI build image that is missing any tool breaks builds, which is worse than shipping the old image.

### Launch With (v1)

- [ ] All table-stakes toolchain packages installed on `almalinux:8` with EL-correct names — `sudo`, `pkgconfig`, `git`, `ruby`, `clang`, `cmake`, `gh` (via GitHub CLI repo), `wget`, `curl`, `libcurl-devel`, `libsecret-devel`, `dbus`, `gnome-keyring`, `ninja-build`, `vulkan-headers`+`vulkan-loader` (via EPEL), `gtk3-devel`, `jq`, `libatomic`
- [ ] Rust 1.87.0 via `rustup` 1.28.2, minimal profile, per-arch SHA256 pinning — amd64 + arm64 only
- [ ] Node 24 via nodesource `setup_24.x`
- [ ] Temurin JDK 25 `jdk-25.0.2+10` tarball + full `JAVA_*` env-var set
- [ ] mold 2.42.0 (upstream static binary) installed and functional as default linker
- [ ] `RUSTUP_HOME` / `CARGO_HOME` / `PATH` / `RUST_VERSION` env vars reproduced
- [ ] dbus machine-id seeding (`/var/lib/dbus/machine-id` + `/etc/machine-id`)
- [ ] `git config --system --add safe.directory '*'`
- [ ] Multi-arch `amd64` + `arm64` build via `docker buildx`
- [ ] Build outputs verified identical to the bullseye image

### Add After Validation (v1.x)

- [ ] Switch to native `-fuse-ld=mold` (drop the `update-alternatives` shim) — only after link-output parity is confirmed
- [ ] dnf layer cleanup / cache trimming for smaller final image

### Future Consideration (v2+)

- [ ] Remove `debian-bullseye` after the new image is verified in CI (grace period per PROJECT.md)
- [ ] AlmaLinux 8 EOL migration (May 2029) — revisit the glibc trade-off then

---

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| Full toolchain parity (all table-stakes packages) | HIGH | MEDIUM | P1 |
| Rust 1.87.0 pinning (per-arch SHA) | HIGH | MEDIUM | P1 |
| Node 24 + Temurin JDK 25 + mold 2.42.0 | HIGH | MEDIUM | P1 |
| Multi-arch amd64 + arm64 | HIGH | HIGH | P1 |
| dbus machine-id + git safe.directory | HIGH | LOW | P1 |
| Native `-fuse-ld=mold` (no alternatives shim) | MEDIUM | LOW | P2 |
| Image size reduction / cache cleanup | LOW | LOW | P2 |
| Drop `debian-bullseye` (grace period) | LOW | LOW | P3 |

**Priority key:**
- P1: Must have for launch (full parity — no partial image is shippable)
- P2: Should have, add when possible (migration benefits, not requirements)
- P3: Nice to have, future consideration

---

## Parity Baseline Comparison

The "competitor" here is the existing `debian-bullseye` image — the reference implementation the new image must reproduce.

| Feature | debian-bullseye (baseline) | almalinux-8 (this port) | Our Approach |
|---------|----------------------------|-------------------------|--------------|
| Base / glibc | Debian bullseye / 2.31 (EOL) | AlmaLinux 8 / 2.28 (supported to 2029) | Parity, with older glibc for wider compat |
| Package manager | `apt` + backports + archive workaround | `dnf` + AppStream + EPEL | Map package names, drop the `Check-Valid-Until=false` hack |
| clang | 11 (predates mold `-fuse-ld`) | ≥17 (AppStream) | Same role; newer version enables native mold |
| mold install | static binary + `update-alternatives` | static binary; optionally native `-fuse-ld=mold` | Parity version, cleaner wiring optional |
| Node 24 | nodesource script | nodesource script | Identical, distro-agnostic |
| Rust 1.87.0 | rustup + per-arch SHA | rustup + per-arch SHA | Identical, drop legacy 32-bit branches |
| Temurin JDK 25 | Adoptium tarball | Adoptium tarball | Identical |
| Arch support | amd64, arm64 (rustup had dead armhf/i386 branches) | amd64 + arm64 only | Cleaner arch set |
| Vulkan | `libvulkan-dev` | `vulkan-headers` + `vulkan-loader` via EPEL | Two-package EL split |

---

## Sources

- `W:\gnus\CIDocker\debian-bullseye\Dockerfile` — exhaustive toolchain inventory (source of truth)
- `W:\gnus\CIDocker\.planning\PROJECT.md` — requirements, out-of-scope, and EL8 package-mapping notes
- Known RHEL 8 / AlmaLinux 8 package naming for the EL equivalents (`libcurl-devel`, `libsecret-devel`, `gtk3-devel`, `vulkan-headers`/`vulkan-loader`, `libatomic`) — MEDIUM confidence; exact `gnome-keyring`/AppStream and EPEL Vulkan availability to be validated at build time

---
*Feature research for: AlmaLinux 8 CI build image (toolchain parity port)*
*Researched: 2026-09-08*
