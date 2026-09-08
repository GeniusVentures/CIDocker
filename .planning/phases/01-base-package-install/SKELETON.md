# Walking Skeleton — CIDocker (AlmaLinux 8 Image Port)

**Phase:** 1
**Generated:** 2026-09-08

## Capability Proven End-to-End

`almalinux-8/Dockerfile` builds with `docker build` and runs; `ldd --version` reports glibc 2.28 and `dnf repolist` shows the ordered enabled repos (baseos, appstream, extras, epel, powertools, gh-cli, nodesource) — image tag `cidocker-almalinux-8:phase1`.

## Architectural Decisions

| Decision | Choice | Rationale |
|---|---|---|
| Base image | `almalinux:8` (rolling, glibc 2.28) | RHEL-clone glibc 2.28 satisfies the ≤2.31 binary-compat constraint; Docker Official Image publishes amd64 + arm64 manifests; supported to May 2029 |
| Package manager | `dnf` | Replaces apt; EL8 has no dpkg/backports repo |
| Repo enablement order | `dnf-plugins-core` → `epel-release` → `powertools` (CRB) → `gh-cli.repo` → NodeSource `setup_24.x`, then `dnf module enable llvm-toolset` | `config-manager` lives in `dnf-plugins-core`; `powertools` is the EL8 CRB id (never `crb`); `gh` exists only in the GitHub CLI repo; clang is delivered only via the llvm-toolset module |
| Compiler | clang via `llvm-toolset` module (17.x); `gcc`/`gcc-c++` kept only for `cc` + libc headers | EL8 clang is module-only; base gcc 8.5 is too old to be the compiler of record |
| Directory layout | `almalinux-8/Dockerfile` alongside `debian-bullseye/Dockerfile` | CI keys off the lowercase distro+version directory name; mirrors the existing convention |

## Stack Touched in Phase 1

- [ ] Base image — `FROM almalinux:8`
- [ ] Repo enablement — 5 ordered repos + `llvm-toolset` module
- [ ] Package install — walking-skeleton slice (Plan 01), full PKG-01 list (Plan 02)
- [ ] Cache cleanup — `dnf clean all` + `rm -rf /var/cache/dnf` in the install layer
- [ ] Build-time verification — `ldd --version` → 2.28, `dnf repolist`, in-image package chain

## Out of Scope (Deferred to Later Slices)

- mold / Node 24 / Rust 1.87.0 / Temurin JDK 25 toolchain — Phase 2
- Parity verification vs `debian-bullseye` + GTK 3.22-vs-3.24 gap audit — Phase 3
- Multi-arch `buildx --platform linux/amd64,linux/arm64` sign-off — Phase 4
- Full PKG-01 package list completion — Plan 02 of this phase (walking skeleton uses a thin slice only)

## Subsequent Slice Plan

Each later phase adds one vertical slice on top of this skeleton without altering its architectural decisions:

- Phase 2: Toolchain install — mold 2.42.0, Node 24, Rust 1.87.0, Temurin JDK 25, env contract
- Phase 3: Parity & verification — toolchain/behavioral parity vs `debian-bullseye`
- Phase 4: Multi-arch verification — amd64 + arm64 buildx sign-off
