# CIDocker

## What This Is

A repository of Docker images used in CI to build the GeniusNetwork projects (SuperGenius, SGProcessingManager). Each directory holds a self-contained base image carrying the full build toolchain — Rust, Node, JDK, mold, clang/cmake, and the GTK/Vulkan native dependencies. The images are consumed by CI pipelines so builds run in a pinned, reproducible environment.

## Core Value

A maintained, security-supported CI base image that reproduces the existing build toolchain, so builds keep working now that Debian bullseye is end-of-life.

## Requirements

### Validated

- ✓ `debian-bullseye/` image — existing; provides Rust 1.87, Node 24, Temurin JDK 25, mold, and GTK/Vulkan toolchain (built on bullseye)
- ✓ `almalinux-8/` image (Phase 1) — builds on `almalinux:8` (glibc 2.28) with the ordered dnf repo set and the full PKG-01 EL8 package list, verified in-image (`ldd --version` → 2.28, `dnf repolist`, `pkg-config --exists vulkan/gtk3/libsecret`)

### Active

- [ ] New `almalinux-8/` image that reproduces the `debian-bullseye` toolchain on AlmaLinux 8 — **Phase 1 (base + packages) complete**; toolchain install (Phase 2), parity (Phase 3), multi-arch (Phase 4) pending
- [ ] Same toolchain parity: Rust 1.87.0, Node 24, Temurin JDK 25, mold, clang, cmake, pkg-config, git, gh, wget, curl, ruby, libsecret, dbus, gnome-keyring, ninja-build, Vulkan, GTK3, jq, libatomic
- [ ] Multi-arch support for `amd64` and `arm64`
- [x] glibc 2.28 (older than bullseye's 2.31) for broad binary compatibility — validated in Phase 1
- [ ] Builds produce the same artifacts as the bullseye image

### Out of Scope

- `armhf` / `i386` — RHEL clones ship neither; JDK already excluded them — don't re-add
- AlmaLinux 9 (glibc 2.34) — rejected in favor of 8 for the older glibc
- Removing `debian-bullseye` — keep both images for now (grace period)

## Context

- Debian bullseye reached end-of-life (2026), forcing the `Acquire::Check-Valid-Until=false` workaround for `apt update`. The migration removes the need for that hack by moving to a still-supported distro.
- The existing image is based on `debian:bullseye` with a `bullseye-backports` apt source. Notable setup choices:
  - `mold` is installed from the upstream static binary because bullseye's clang 11 predates `-fuse-ld=mold`.
  - Node 24 comes from the nodesource `setup_24.x` script.
  - Rust 1.87.0 is installed via `rustup` with per-architecture SHA256 pinning.
  - Temurin JDK 25 is installed from the Adoptium tarball (distro-agnostic).
- RHEL 8 clone considerations for the port:
  - Package manager is `dnf`, not `apt`; several Debian package names map to different EL names (e.g. `libcurl-devel`, `libsecret-devel`, `gtk3-devel`, `vulkan-headers`/`vulkan-loader`).
  - `gh` (GitHub CLI) is not in base EL repos — needs the GitHub CLI repo or an equivalent source.
  - Some packages (notably Vulkan) may require EPEL on EL 8.
  - EL 8's appstream clang is newer than bullseye's 11, so `mold` should work natively via `-fuse-ld=mold` without the manual `update-alternatives` shim.

## Constraints

- **glibc**: must stay ≤ 2.31 for binary compatibility — satisfied by AlmaLinux 8's glibc 2.28
- **Support lifetime**: AlmaLinux 8 maintenance ends May 2029 (vs 2032 for Alma 9)
- **Multi-arch**: `amd64` + `arm64` only — RHEL clones provide no 32-bit ARM/x86
- **Toolchain parity**: the new image must reproduce the bullseye toolchain so build outputs are identical

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| AlmaLinux 8 (RHEL 8 rebuild) | Older glibc 2.28 for broad binary compatibility; Alma preferred over Rocky | Validated in Phase 1 — image builds on `almalinux:8` |
| `amd64` + `arm64` only | RHEL clones ship only these; JDK already excluded 32-bit targets | — Pending (Phase 4) |
| Keep `debian-bullseye` alongside | Grace period until the new image is verified in CI | — Pending (grace period) |
| glibc 2.28 over 2.34 | Trade 2029 EOL for wider runtime compatibility | Validated in Phase 1 — `ldd --version` → 2.28 |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd-transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd-complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-09-08 — Phase 1 (Base & Package Install) complete*
