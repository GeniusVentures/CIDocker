# Project Research Summary

**Project:** CIDocker
**Domain:** CI build-image repository (self-contained Dockerfiles carrying a Rust/Node/JDK/mold/clang/cmake/GTK/Vulkan toolchain)
**Researched:** 2026-09-08
**Confidence:** HIGH (overall); MEDIUM on a handful of per-package repo placements — flagged inline

## Executive Summary

CIDocker is a repository of **self-contained CI base images**, one directory per distro, each a single `Dockerfile` carrying the full GeniusNetwork build toolchain (SuperGenius, SGProcessingManager). The new `almalinux-8/` image is a **parity port** of the existing `debian-bullseye/` image onto AlmaLinux 8 (glibc 2.28, amd64 + arm64) — not a new product. Experts build this kind of image bottom-up as ordered layers: repo enablement, a single `dnf install` transaction for all distro packages, then upstream static/tarball installs (mold, rustup, Temurin JDK, NodeSource) in their own rarely-changing layers, topped by `ENV` and runtime glue.

The recommended approach is a single `almalinux-8/Dockerfile` mirroring the bullseye convention: `dnf-plugins-core` first, then PowerTools/CRB (`powertools` repo id on EL8) and the GitHub CLI rpm repo, then NodeSource, then one `dnf install` covering the full mapped package list, followed by the **unchanged** mold 2.42.0 / rustup 1.28.2 (Rust 1.87.0) / Temurin JDK 25.0.2+10 / Node 24 recipes with the `armhf`/`i386` branches deleted and `uname -m` replacing `dpkg --print-architecture`. The project's earlier hypothesis that Vulkan requires EPEL is **corrected**: `vulkan-loader` + `vulkan-loader-devel` + `vulkan-headers` are in AppStream on EL8, so EPEL is not required by default.

The key risks are, in order: **(1)** Node 24 sits *exactly* on the glibc 2.28 floor — the base choice has zero headroom and Node must come from a source built for ≥ 2.28 (the official `nodejs.org` tarball is the safest); **(2)** `clang` is an AppStream *module* (`llvm-toolset`), not a base package, and the base GCC 8.5 cannot pass `-fuse-ld=mold`, so the `update-alternatives` mold shim must be kept for link parity; **(3)** GTK 3.22 (EL8) vs 3.24 (bullseye) is the single biggest parity risk and a potential blocker — the consuming projects' GTK API usage must be audited before assuming parity. AlmaLinux 8 EOL (May 2029) is a real, logged expiry of the old-glibc tradeoff.

## Key Findings

### Recommended Stack

AlmaLinux 8 (rolling `almalinux:8`, currently 8.10, multi-arch amd64+arm64) with `dnf` as package manager. glibc 2.28 is verified compatible with every toolchain component — JDK 25 needs ≥ 2.17, Rust 1.87 and mold need ≤ 2.28, and Node 24 needs **exactly ≥ 2.28** (the binding constraint). The critical EL8 structural facts: **clang is delivered only via the `llvm-toolset` AppStream module** (streams 17–21; default 17.0.6), the base GCC is 8.5.0 (too old for `-fuse-ld=mold`), and several Debian packages map to different EL names and repos.

**Core technologies:**
- **`almalinux:8`** (rolling official image) — maintained base, glibc 2.28 for broad binary compat; publishes amd64 + arm64 manifests.
- **`dnf` + `dnf-plugins-core`** — package manager; `dnf config-manager` for repo enablement must be installed first (not guaranteed in the minimal image).
- **PowerTools/CRB** (`powertools` id on EL8) — source of `libcurl-devel`, `ninja-build`, and dev headers RHEL strips from AppStream/BaseOS.
- **GitHub CLI rpm repo** (`cli.github.com/packages/rpm/gh-cli.repo`) — `gh` is in no EL repo.
- **NodeSource `rpm.nodesource.com/setup_24.x`** — Node 24; rpm build supports x86_64 + arm64; the only change vs bullseye is the host.
- **AppStream modules** — `llvm-toolset` (clang 17+) and `ruby` streams replace bullseye's plain `clang`/`ruby-full`.

**Package mapping (Debian → EL8):** `pkg-config`→`pkgconf-pkg-config`, `ruby-full`→`ruby`+`ruby-devel`, `libcurl4-openssl-dev`→`libcurl-devel` (PowerTools/CRB), `libsecret-1-dev`→`libsecret-devel`, `libgtk-3-dev`→`gtk3-devel`, `libvulkan-dev`→`vulkan-loader`+`vulkan-loader-devel`+`vulkan-headers` (**AppStream — EPEL not needed**), `libatomic1`→`libatomic`, `gh`→GitHub CLI repo, plus `gcc gcc-c++ make binutils` (which Debian pulled implicitly via build-essential and EL8 does **not**). Keep the **unchanged** mold 2.42.0 static tarball + `update-alternatives` shim, rustup 1.28.2 → Rust 1.87.0, Temurin JDK 25.0.2+10 tarball, and NodeSource script.

### Expected Features

**Must have (table stakes — builds break without any of these):**
- Full toolchain parity: Rust 1.87.0 (rustup, per-arch SHA256 pins), Node 24, Temurin JDK 25.0.2+10, mold 2.42.0 as default linker, clang, cmake, ninja-build, pkg-config, git, gh, wget, curl, ruby, libcurl-devel, libsecret-devel, dbus, gnome-keyring, Vulkan (headers+loader), gtk3-devel, jq, libatomic, sudo.
- Exact env-var contract: `RUSTUP_HOME`, `CARGO_HOME`, `PATH`, `RUST_VERSION`, and the full `JAVA_*`/`JAVA_HOME`/`JDK_HOME` set.
- dbus machine-id seeding (`/var/lib/dbus/machine-id` + `/etc/machine-id`) and `git config --system --add safe.directory '*'`.
- Multi-arch `amd64` + `arm64` via `docker buildx`.

**Should have (differentiators — migration benefits, not requirements):**
- No EOL `apt` workaround — drops the `Acquire::Check-Valid-Until=false` hack entirely.
- Native `-fuse-ld=mold` support in clang 17+ (bullseye's clang 11 predates it) — enable only after link parity is verified.
- Still-supported security patches (AlmaLinux 8 maintained to May 2029).

**Defer (v2+):**
- Remove `debian-bullseye/` after the new image is verified in CI (grace period per PROJECT.md).
- Image-size/cache trimming beyond `dnf clean all`.
- AlmaLinux 8 EOL migration (May 2029) — revisit the glibc tradeoff then.

### Architecture Approach

One self-contained directory per distro (`almalinux-8/` mirroring `debian-bullseye/`), a single `Dockerfile` per image, no shared base or multi-stage parent. The image is a bottom-up layer stack: `FROM almalinux:8` → `ENV` (Rust/cargo paths) → repo enablement → single `dnf install` layer → upstream tarball layers (mold+Node, then Rust, then JDK) → `ENV` + runtime glue (git safe.directory, dbus machine-id). Arch-dependent downloads use `uname -m` with reduced 2-arm `case` maps (`x86_64`/`aarch64`) and a hard `exit 1` default.

**Major components:**
1. **Base** (`FROM almalinux:8`) — OS + glibc 2.28, multi-arch manifest.
2. **Repo enablement layer** — `dnf-plugins-core`, then PowerTools/CRB + GitHub CLI repo (+ NodeSource).
3. **dnf install layer** — all distro packages in one transaction, `dnf clean all` at the end.
4. **mold** — upstream static tarball + `update-alternatives` shim (kept for parity).
5. **node / rust / jdk** — NodeSource script, rustup-init (SHA256-pinned), Adoptium tarball.
6. **ENV + glue layer** — `/etc/profile.d/java-env.sh` + Dockerfile `ENV`, git safe.directory, dbus machine-id.

### Critical Pitfalls

1. **Node 24 sits exactly on the glibc 2.28 floor (zero headroom)** — install Node from a source documented to target ≥ 2.28 (official `nodejs.org` tarball is safest), and add a `node -e 'process.exit(0)'` smoke assertion. Watch for `env: 'node': No such file or directory` (classic glibc-mismatch signature).
2. **`clang` is an AppStream module and the base GCC 8.5 can't `-fuse-ld=mold`** — install via `dnf module enable llvm-toolset -y && dnf install -y clang`, and **keep** the `update-alternatives` mold shim (it's still required for any link driven by `gcc`/`cc`); verify module state persists into the final image.
3. **GTK 3.22 (EL8) vs 3.24 (bullseye) is the biggest parity risk** — audit the consuming projects' GTK API usage before assuming parity; post-3.22 APIs will fail to compile and there is **no package fix on EL8** (potential blocker).
4. **`gh`, `ninja-build`, `libcurl-devel` live outside default repos** — `gh` needs the GitHub CLI repo; `ninja-build` is in PowerTools/CRB; `libcurl-devel` in PowerTools/CRB. Enable repos before install, verify ids at build time (`dnf repolist`), and keep GPG checks on.
5. **`apt -t backports` has no dnf equivalent** — repos/modules must be enabled individually, and dnf cache must be cleaned (`dnf clean all; rm -rf /var/cache/dnf`) or the image balloons.
6. **dbus/keyring need explicit sub-packages + machine-id** — EL8 splits `dbus-daemon`/`dbus-tools` from `dbus`; reproduce the exact machine-id bootstrap or keyring-dependent CI steps hang silently.

## Implications for Roadmap

Based on combined research, suggested phase structure:

### Phase 1: Package Install (dnf + repo enablement)
**Rationale:** Everything downstream depends on distro packages being present and resolvable; the repo-enablement order is the highest-dependency surface and the place where name/repo mistakes surface first. Comes first because toolchain layers need the tools (`curl`, `wget`, `tar`, `sha256sum`, `chkconfig`/`update-alternatives`) this phase installs.
**Delivers:** `almalinux-8/Dockerfile` with `FROM almalinux:8`, `ENV` block, ordered repo enablement (`dnf-plugins-core` → PowerTools/CRB → GitHub CLI repo → NodeSource; EPEL only as conditional fallback), and one `dnf install` transaction with the full mapped package list + `dnf clean all`.
**Addresses:** All table-stakes distro packages (sudo, pkgconf-pkg-config, git, ruby+ruby-devel, clang (module), cmake, make, gcc, gcc-c++, binutils, gh, wget, curl, libcurl-devel, libsecret-devel, dbus+dbus-daemon+dbus-tools, gnome-keyring, ninja-build, vulkan-loader+devel+headers, gtk3-devel, jq, libatomic, openssl-devel).
**Avoids:** Pitfalls 2 (clang module enablement), 3 (ninja in PowerTools), 4 (gh repo), 5 (dnf semantics + cache cleanup), 7/8 (repo-id and dbus sub-package correctness).

### Phase 2: Toolchain Install (mold, Rust, Node, JDK + env)
**Rationale:** These four components are upstream tarballs/scripts unchanged from bullseye, so they form a natural, low-risk grouping that is independent of the package layer once it exists. Rarely-changing, so they belong in their own cache-friendly layers after the package layer.
**Delivers:** mold 2.42.0 (static tarball + `update-alternatives` shim), Node 24 (NodeSource), Rust 1.87.0 (rustup-init, per-arch SHA256), Temurin JDK 25.0.2+10 (Adoptium tarball + `JAVA_*` env), with `armhf`/`i386` branches deleted and `uname -m` 2-arm maps.
**Uses:** Stack elements — rustup 1.28.2, Adoptium tarball, mold release tarball, NodeSource rpm script (all distro-agnostic).
**Implements:** Architecture components 4–6 (mold, node/rust/jdk layers, ENV layer).
**Avoids:** Pitfall 1 (Node glibc floor — add `node -e` smoke assert), Pitfall 2 (keep mold shim), the "floating latest" and "skipped SHA256" security mistakes.

### Phase 3: Parity / Verification (behavioral parity vs bullseye)
**Rationale:** This is the phase with the highest uncertainty and the most likely blocker (GTK 3.22 vs 3.24). It must follow the build phases but precedes multi-arch sign-off because architectural parity is pointless if behavioral parity fails.
**Delivers:** glibc/version smoke tests (`ldd --version`, `node -e`, `clang --version`, `ld --version`=mold, `ninja --version`, `gh --version`, `pkg-config --exists vulkan`), a build-the-same-sample-project artifact diff against bullseye, and a headless dbus/keyring smoke test.
**Addresses:** The "build outputs identical to bullseye" table stake; the v1.1 native `-fuse-ld=mold` evaluation.
**Avoids:** Pitfall 5 (GTK API audit — surface any post-3.22 API usage as a blocker early), Pitfall 2 (clang-module persistence check), Pitfall 8 (keyring smoke test), clang 11→17 behavioral drift.

### Phase 4: Multi-arch Verification (amd64 + arm64 via buildx)
**Rationale:** Multi-arch is a hard acceptance criterion but is mostly orchestration once the Dockerfile is arch-clean; it verifies the remaining MEDIUM-confidence items (aarch64 availability of `gnome-keyring`, `vulkan-headers`, `gh`) that only exercise on the arm64 build. Ordered last so arch-specific fixes don't churn the parity work.
**Delivers:** `docker buildx build --platform linux/amd64,linux/arm64 --push` producing a two-digest manifest; QEMU/binfmt setup (or `docker/setup-qemu-action` in CI); arm64 run smoke tests for every tool.
**Uses:** Architecture multi-arch approach (buildx + `uname -m`), QEMU binfmt.
**Avoids:** Pitfall 4 (gh aarch64 repo coverage), "exec format error" (missing binfmt), the aarch64 validation flags from STACK.md.

### Phase Ordering Rationale

- **Dependencies drive the order:** repo enablement → packages → upstream toolchain → verification → multi-arch. Toolchain layers (Phase 2) require Phase 1's `wget`/`curl`/`tar`/`chkconfig`; verification (Phase 3) requires the full toolchain; multi-arch (Phase 4) requires an arch-clean Dockerfile.
- **Grouping matches architecture:** the four upstream tarball/script installs (mold/Node/Rust/JDK) share one pattern and belong together; all dnf packages belong in one transaction.
- **Risk is front-loaded in verification:** GTK parity and clang drift are surfaced in Phase 3 before any multi-arch sign-off, so arch fixes don't mask behavioral gaps.

### Research Flags

Phases likely needing deeper research during planning:
- **Phase 3 (Parity/Verification):** GTK 3.22 vs 3.24 API audit against SuperGenius/SGProcessingManager is the highest-uncertainty item — needs `/gsd-plan-phase --research-phase` on the actual consuming projects' GTK API usage. Also Ruby stream selection (bullseye 2.7 vs EL8 default/available streams) and clang 11→17 codegen drift.
- **Phase 1 (Package Install):** validate the conflicting repo placements at build time — `ninja-build` (AppStream per STACK.md MEDIUM vs PowerTools/CRB per PITFALLS.md HIGH) and `libcurl-devel` (PowerTools/CRB per STACK.md vs BaseOS per ARCHITECTURE.md). Verify via `dnf repolist`/`dnf info`.

Phases with standard patterns (skip research-phase):
- **Phase 2 (Toolchain Install):** unchanged upstream tarball/script recipes from bullseye — well-documented, no research needed beyond arch-map trimming.
- **Phase 4 (Multi-arch):** `buildx` + `uname -m` multi-arch is an established, well-documented pattern.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | Base image, core tool versions, and glibc floors verified against official indexes/sources; MEDIUM on a few per-package repo placements (Vulkan, libsecret, ninja). |
| Features | MEDIUM-HIGH | Toolchain inventory exhaustive from the existing Dockerfile; EL name mappings standard but several flagged for build-time validation. |
| Architecture | HIGH | Mirrors the existing repo convention; commands verified against AlmaLinux/NodeSource/GitHub CLI docs. |
| Pitfalls | HIGH | glibc floors for JDK (2.17), Node (2.28), Rust (2.17) from primary build configs; mold floor MEDIUM-HIGH. |

**Overall confidence:** HIGH — the port is well-understood, with isolated MEDIUM items that resolve cheaply at build time.

### Gaps to Address

- **Vulkan repo placement:** STACK.md (MEDIUM) suggested EPEL/CRB, but ARCHITECTURE.md and PITFALLS.md (HIGH, verified via live repo listings) place `vulkan-loader`/`vulkan-loader-devel`/`vulkan-headers` in AppStream. Resolution: AppStream is authoritative; treat EPEL as a conditional fallback only if `dnf install` resolution fails.
- **`ninja-build` repo:** AppStream (STACK.md MEDIUM) vs PowerTools/CRB (PITFALLS.md HIGH). Resolve at build time with `dnf repolist`; keep the `--set-enabled powertools` step regardless since `libcurl-devel` also needs it.
- **`libcurl-devel` repo:** PowerTools/CRB (STACK.md HIGH, and the canonical "runtime BaseOS / dev CRB" split) vs BaseOS (ARCHITECTURE.md table). Resolve at build time; the PowerTools/CRB reading is primary.
- **GTK 3.22 vs 3.24 API usage:** must audit the consuming projects' GTK API surface before assuming parity; potential blocker with no EL8 package fix.
- **Ruby stream parity:** pin an explicit `ruby:<stream>` matching bullseye's 2.7 where needed rather than accepting the default stream.
- **aarch64 availability of `gnome-keyring` and `vulkan-headers`:** flagged MEDIUM; exercised in Phase 4.
- **clang 11→17 behavioral drift:** newer clang emits different warnings/optimizations; verify artifacts still match in Phase 3.
- **AlmaLinux 8 EOL (May 2029):** record a re-evaluation checkpoint in PROJECT.md/roadmap now; act later.

## Sources

### Primary (HIGH confidence)
- Docker Hub `library/almalinux` — official tags (`:8`, `:8.10`), multi-arch amd64/arm64 manifests.
- AlmaLinux wiki (Repositories, EPEL, PowerTools/CRB) — repo enablement, `powertools` id on EL8.
- `nodejs/node` BUILDING.md — official Node binary floor "glibc >= 2.28, kernel >= 4.18".
- `adoptium/temurin-build` FAQ.md + `ci-jenkins-pipelines` jdk25u config — Temurin JDK 25 built on CentOS 7 (glibc 2.17).
- `rust-lang/rust` CI Dockerfiles (`dist-x86_64-linux` / `dist-aarch64-linux`) — Rust minimum glibc 2.17.
- GitHub CLI install docs + live rpm repodata — `gh-cli.repo`, aarch64/x86_64 coverage.
- NodeSource distributions — `rpm.nodesource.com/setup_24.x`, x86_64 + arm64.
- AlmaLinux 8 live repo listings (AppStream/BaseOS/PowerTools) — clang 17.0.6, cmake 3.26.5, gtk3-devel 3.22.30, vulkan-loader/headers in AppStream, ninja-build in PowerTools, gnome-keyring 3.28.2, libsecret 0.18.6.
- Existing `W:\gnus\CIDocker\debian-bullseye\Dockerfile` — authoritative parity source of truth.

### Secondary (MEDIUM confidence)
- `rui314/mold` README.md + `dist.sh` — static build, libstdc++ statically linked; GCC ≥ 12.1 for `-fuse-ld=mold` (mold glibc floor MEDIUM-HIGH).
- Repology — `vulkan-headers`/`vulkan-loader` in AlmaLinux 8 AppStream.
- AlmaLinux 8.10 release notes — Ruby 3.3 / Git 2.43 updates; aarch64 + x86_64 support.

### Tertiary (LOW confidence)
- `W:\gnus\CIDocker\.planning\PROJECT.md` — earlier hypothesis that Vulkan "may require EPEL" (superseded by verified AppStream finding).
- `W:\gnus\CIDocker\.planning\research\STACK.md` package-repo placements flagged MEDIUM (Vulkan, libsecret, ninja) — to be validated at build time.

---
*Research completed: 2026-09-08*
*Ready for roadmap: yes*
