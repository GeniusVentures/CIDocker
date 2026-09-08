# Requirements: CIDocker

**Defined:** 2026-09-08
**Core Value:** A maintained, security-supported CI base image that reproduces the existing build toolchain, so builds keep working now that Debian bullseye is end-of-life.

## v1 Requirements

Requirements for the AlmaLinux 8 image. Each maps to roadmap phases.

### Base & Repos

- [x] **BASE-01**: Image is based on `almalinux:8` (glibc 2.28)
- [x] **BASE-02**: dnf repositories are enabled in order — `dnf-plugins-core`, `epel-release`, PowerTools/CRB, GitHub CLI repo, NodeSource
- [ ] **BASE-03**: Image builds for `amd64` and `arm64` only (no `armhf`/`i386`)

### System Packages

- [ ] **PKG-01**: Installs EL8 equivalents of every bullseye package — `libcurl-devel`, `libsecret-devel`, `gtk3-devel`, `vulkan-loader` + `vulkan-loader-devel` + `vulkan-headers`, `libatomic`, `pkgconf-pkg-config`, `ruby` + `ruby-devel`, `clang` (via llvm-toolset module), `cmake`, `ninja-build`, `git`, `gh`, `wget`, `curl`, `dbus`, `gnome-keyring`, `jq`, `sudo`, plus `gcc`/`gcc-c++`/`make`/`binutils`
- [ ] **PKG-02**: Seeded dbus `machine-id` and `git` safe.directory are configured

### Toolchain

- [ ] **TOOL-01**: mold 2.42.0 installed from upstream tarball with the `update-alternatives` ld shim (GCC 8.5 cannot pass `-fuse-ld=mold`)
- [ ] **TOOL-02**: Node 24 installed (NodeSource, or official tarball to hold the glibc 2.28 floor)
- [ ] **TOOL-03**: Rust 1.87.0 installed via SHA256-pinned rustup, `amd64` + `arm64` branches only
- [ ] **TOOL-04**: Temurin JDK 25 installed via Adoptium tarball, `amd64` + `arm64` branches only
- [ ] **TOOL-05**: Environment contract preserved (`RUSTUP_HOME`, `CARGO_HOME`, `JAVA_HOME`, `PATH`)

### Parity & Verification

- [ ] **PAR-01**: Built image carries the same toolchain versions as `debian-bullseye` (Rust 1.87.0, Node 24, JDK 25, mold 2.42.0)
- [ ] **PAR-02**: GTK version gap (EL8 3.22 vs bullseye 3.24) is verified as non-blocking for consuming builds
- [ ] **PAR-03**: Multi-arch build verified with `docker buildx --platform linux/amd64,linux/arm64`

## v2 Requirements

Deferred to a future release. Tracked but not in current roadmap.

### Lifecycle

- **LIFE-01**: Deprecate/remove `debian-bullseye` once the AlmaLinux 8 image is validated in CI
- **LIFE-02**: Re-evaluate glibc target before AlmaLinux 8 EOL (May 2029)

## Out of Scope

Explicitly excluded. Documented to prevent scope creep.

| Feature | Reason |
|---------|--------|
| `armhf` / `i386` | RHEL clones ship neither; JDK already excluded them |
| AlmaLinux 9 (glibc 2.34) | Rejected in favor of 8 for the older glibc |
| Second / newer glibc in the image | Would defeat the compatibility goal |
| Unpinned "latest" toolchains | Parity requires exact versions |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| BASE-01 | Phase 1 | Complete |
| BASE-02 | Phase 1 | Complete |
| BASE-03 | Phase 4 | Pending |
| PKG-01 | Phase 1 | Pending |
| PKG-02 | Phase 2 | Pending |
| TOOL-01 | Phase 2 | Pending |
| TOOL-02 | Phase 2 | Pending |
| TOOL-03 | Phase 2 | Pending |
| TOOL-04 | Phase 2 | Pending |
| TOOL-05 | Phase 2 | Pending |
| PAR-01 | Phase 3 | Pending |
| PAR-02 | Phase 3 | Pending |
| PAR-03 | Phase 4 | Pending |

**Coverage:**

- v1 requirements: 13 total
- Mapped to phases: 13
- Unmapped: 0 ✓

---
*Requirements defined: 2026-09-08*
*Last updated: 2026-09-08 after initial definition*
