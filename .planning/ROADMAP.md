# Roadmap: CIDocker — AlmaLinux 8 Image Port

## Overview

Port the existing `debian-bullseye` CI build image onto AlmaLinux 8, reproducing the
full pinned toolchain (Rust 1.87.0, Node 24, Temurin JDK 25, mold 2.42.0, clang/cmake,
GTK/Vulkan) on glibc 2.28 for `amd64` + `arm64`. The work is delivered as a single
`almalinux-8/Dockerfile` built bottom-up: base + repo enablement → system packages →
upstream toolchain tarballs → behavioral parity verification → multi-arch sign-off.

## Phases

**Phase Numbering:**

- Integer phases (1, 2, 3, 4): Planned milestone work

- [ ] **Phase 1: Base & Package Install** - `almalinux:8` base, ordered dnf repo enablement, full EL8 package set
- [ ] **Phase 2: Toolchain Install** - mold, Node 24, Rust 1.87.0, Temurin JDK 25, env contract, runtime glue
- [ ] **Phase 3: Parity & Verification** - toolchain/behavioral parity vs `debian-bullseye`, GTK gap audit
- [ ] **Phase 4: Multi-arch Verification** - `amd64` + `arm64` buildx sign-off, 32-bit exclusion

## Phase Details

### Phase 1: Base & Package Install

**Goal**: The `almalinux-8` image is based on AlmaLinux 8 (glibc 2.28) with every required EL8 system package installed from correctly-enabled repositories.
**Mode:** mvp
**Depends on**: Nothing (first phase)
**Requirements**: BASE-01, BASE-02, PKG-01
**Success Criteria** (what must be TRUE):

  1. `almalinux-8/Dockerfile` starts `FROM almalinux:8` and the resulting image reports glibc 2.28 via `ldd --version`.
  2. The image builds successfully with `dnf-plugins-core`, PowerTools/CRB (`powertools`), the GitHub CLI repo, and NodeSource enabled in the required order (evidenced by `dnf repolist` in the build output).
  3. The full mapped EL8 package list installs in one dnf transaction — `sudo`, `pkgconf-pkg-config`, `git`, `ruby`+`ruby-devel`, `clang` (via `llvm-toolset` module), `cmake`, `gh`, `wget`, `curl`, `libcurl-devel`, `libsecret-devel`, `dbus`+`dbus-daemon`+`dbus-tools`, `gnome-keyring`, `ninja-build`, `vulkan-loader`+`vulkan-loader-devel`+`vulkan-headers`, `gtk3-devel`, `jq`, `libatomic`, plus `gcc`/`gcc-c++`/`make`/`binutils`.
  4. `docker build` completes with `dnf clean all`, leaving no dnf package cache and a lean image comparable in size to `debian-bullseye`.

**Plans**: 2 plans

Plans:
**Wave 1**

- [ ] 01-01-PLAN.md — Walking skeleton: base + ENV + ordered repos + thin package slice, SKELETON.md contract

**Wave 2** *(blocked on Wave 1 completion)*

- [ ] 01-02-PLAN.md — Full PKG-01 package set (one dnf transaction) + in-image verification chain + clean build

### Phase 2: Toolchain Install

**Goal**: The image carries the full pinned toolchain and environment contract, completing it as a drop-in replacement for `debian-bullseye`.
**Mode:** mvp
**Depends on**: Phase 1
**Requirements**: TOOL-01, TOOL-02, TOOL-03, TOOL-04, TOOL-05, PKG-02
**Success Criteria** (what must be TRUE):

  1. `ld --version` reports mold 2.42.0 as the default linker (upstream static tarball + `update-alternatives` shim).
  2. `node --version` reports Node 24.x and `node -e 'process.exit(0)'` exits cleanly (glibc 2.28 floor respected).
  3. `rustc --version` reports Rust 1.87.0 installed via SHA256-verified rustup; the case maps contain only `x86_64`/`aarch64` (no `armhf`/`i386`).
  4. `java -version` reports Temurin JDK 25; `JAVA_HOME`, `JDK_HOME`, `RUSTUP_HOME`, `CARGO_HOME`, and `PATH` match the bullseye env contract.
  5. `git config --system --get safe.directory` returns `*`, and `/var/lib/dbus/machine-id` + `/etc/machine-id` are seeded and identical.

**Plans**: TBD

### Phase 3: Parity & Verification

**Goal**: The AlmaLinux 8 image is verified to behave identically to `debian-bullseye` for the consuming builds.
**Mode:** mvp
**Depends on**: Phase 2
**Requirements**: PAR-01, PAR-02
**Success Criteria** (what must be TRUE):

  1. The toolchain version matrix matches bullseye exactly — Rust 1.87.0, Node 24, JDK 25, mold 2.42.0 — verified by running both images side-by-side.
  2. A representative sample build (SuperGenius/SGProcessingManager artifact) compiles and produces artifacts equivalent to the bullseye image.
  3. The GTK 3.22 (EL8) vs 3.24 (bullseye) gap is confirmed non-blocking — the consuming projects' GTK API usage compiles against EL8 `gtk3-devel`.
  4. Clang 11→17 drift and Ruby stream differences are verified not to change build behavior or outputs.

**Plans**: TBD

### Phase 4: Multi-arch Verification

**Goal**: The image is verified to build and run on `amd64` and `arm64` — and only those architectures.
**Mode:** mvp
**Depends on**: Phase 3
**Requirements**: BASE-03, PAR-03
**Success Criteria** (what must be TRUE):

  1. `docker buildx build --platform linux/amd64,linux/arm64 --push` produces a single manifest with both digests.
  2. The Dockerfile contains no `armhf`/`i386` branches (2-arm `x86_64`/`aarch64` maps with a hard `exit 1` default).
  3. A run smoke test of every tool passes on `arm64` (`gnome-keyring`, `vulkan-headers`, `gh` all resolve on aarch64).
  4. CI pulls the multi-arch image by tag; `amd64` and `arm64` pulls resolve to the correct architecture.

**Plans**: TBD

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3 → 4

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Base & Package Install | 0/2 | Planned | - |
| 2. Toolchain Install | 0/TBD | Not started | - |
| 3. Parity & Verification | 0/TBD | Not started | - |
| 4. Multi-arch Verification | 0/TBD | Not started | - |
