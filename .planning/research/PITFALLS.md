# Pitfalls Research

**Domain:** AlmaLinux 8 CI build image (port of `debian-bullseye` Dockerfile)
**Researched:** 2026-09-08
**Confidence:** HIGH

> Scope note: every pitfall below is specific to this EL8 port, not generic Docker advice.
> The single highest-risk question — "does glibc 2.28 satisfy every toolchain component?" — is answered
> **YES**, but Node 24 sits *exactly* on the boundary. See the compatibility table in Pitfall 1.

---

## glibc Compatibility Verdicts (explicit)

Verified against primary sources (build recipes / CI configs, not marketing pages):

| Component | Minimum glibc | Verdict vs AlmaLinux 8 (glibc 2.28) | Confidence | Source |
|-----------|---------------|-------------------------------------|------------|--------|
| **Temurin JDK 25** (x64 + aarch64) | **2.17** (built on CentOS 7) | ✅ COMPATIBLE — far below 2.28 | HIGH | Adoptium `temurin-build/FAQ.md` + `ci-jenkins-pipelines` jdk25u config (`centos7_build_image`, gcc devkit `Centos7.9.2009`) |
| **Node 24 official binaries** (x64 + arm64) | **2.28** (kernel ≥ 4.18) | ⚠️ COMPATIBLE — *exactly* at the boundary | HIGH | `nodejs/node` BUILDING.md ("glibc >= 2.28 … e.g. Debian 10, RHEL 8, Ubuntu 20.04") |
| **Rust 1.87 toolchain** (x64 + aarch64) | **2.17** (built on CentOS 7) | ✅ COMPATIBLE | HIGH | `rust-lang/rust` CI Dockerfiles (`dist-x86_64-linux` and `dist-aarch64-linux` both `FROM centos:7`, "minimum glibc 2.17") |
| **mold static binary** | **~2.24** (built on Debian 9 Stretch; libstdc++ statically linked, glibc dynamic) | ✅ COMPATIBLE | MEDIUM-HIGH | `mold/dist.sh` ("reasonably old Debian… Debian 9 (Stretch)… statically linked to libstdc++") |
| **GitHub CLI (gh)** | **n/a** (Go static binary) | ✅ COMPATIBLE — no glibc floor | HIGH | Go build; release tarballs are static; rpm repo carries `aarch64` |

**The knife-edge:** Node 24 is the *only* component whose floor equals 2.28. glibc 2.28 is the
*minimum*, not merely "known to work" — every other component is far below it. This validates the
AlmaLinux 8 choice, but it also means there is **zero headroom**: you cannot later downgrade the base
or use a container with an older glibc, and the Node binaries must come from a source built for ≥ 2.28.

---

## Critical Pitfalls

### Pitfall 1: Node 24 official binaries require glibc ≥ 2.28 — the base choice lives on a knife-edge

**What goes wrong:**
If Node 24 is installed from a source built against a *newer* glibc than 2.28, or if anyone later
switches the base image to something with glibc < 2.28, `node` fails to start with
`GLIBC_2.xx not found` / `version GLIBC_2.xx not found`.

**Why it happens:**
Node.js upstream explicitly documents the official Linux x64/arm64 binaries as
"kernel >= 4.18, glibc >= 2.28" (BUILDING.md footnote [^6]: "Binaries produced on these systems are
compatible with glibc >= 2.28 and libstdc++ >= 6.0.25 (`GLIBCXX_3.4.25`)… such as Debian 10, RHEL 8
and Ubuntu 20.04"). glibc 2.28 is therefore the *floor*, and AlmaLinux 8 is the oldest distro that
still satisfies it. There is no safety margin.

**How to avoid:**
- Pin the install to a source known to target ≥ 2.28 and ≤ 2.28: the **official `nodejs.org`
  tarball** (`node-v24.x-linux-{x64,arm64}.tar.xz`) is the safest and matches the Rust/JDK
  tarball pattern already used. It is explicitly RHEL-8-compatible.
- If you keep the NodeSource route instead, note `setup_24.x` supports `aarch64` + `x86_64` and
  uses the `nodistro` repo (`rpm.nodesource.com/pub_24.x/nodistro/nodejs/$arch`); its el-family
  packages are built for RHEL-family glibc and are compatible, but they are a *rebuild* — the
  official tarball is the one the 2.28 guarantee is stated for.
- Add a smoke assertion in the image build: `node -e 'process.exit(0)'` after install.

**Warning signs:**
`/usr/bin/env: 'node': No such file or directory` right after a "successful" Node install (this is
the classic glibc-mismatch failure signature on x86_64), or `node: error while loading shared
libraries: libstdc++.so.6: cannot open shared object file`.

**Phase to address:** Toolchain install phase (Node) + a dedicated glibc-verification step.

---

### Pitfall 2: `clang` is an AppStream *module*, not a base package — and `-fuse-ld=mold` only works for clang, not the base GCC

**What goes wrong:**
Two related failures:
1. `dnf install clang` fails with `Error: Unable to find a match: clang` in a minimal container
   because clang is delivered only via the `llvm-toolset` AppStream module.
2. Assuming the `update-alternatives` mold shim from the bullseye Dockerfile can simply be deleted
   because "EL8 clang is newer than clang 11". The shim registers `/usr/local/bin/ld.mold` as the
   system `ld`; removing it silently changes every build that invokes the linker through `gcc`/`cc`
   (the default Rust/C driver) back to `ld.bfd`.

**Why it happens:**
- AlmaLinux 8 / RHEL 8 AppStream ships clang as the `llvm-toolset` module (verified streams:
  clang 17, 18, 19, 20, 21). There is no plain `clang` package; `dnf install clang` must resolve
  through a module stream.
- `-fuse-ld=mold` support is per-driver: **clang supports it** (all EL8 llvm-toolset clang versions
  17+ support it), but **the base GCC is 8.5.0**, and `-fuse-ld` only accepts `mold` in **GCC ≥ 12.1**
  (mold README: "For GCC 12.1.0 or later: pass -fuse-ld=mold… For GCC before 12.1.0 … use -B").
  Newer GCC exists only as `gcc-toolset-10/11/12/13/14/15` modules, which are not enabled by default.

**How to avoid:**
- Install clang explicitly as a module: `dnf module enable llvm-toolset -y && dnf install -y clang`
  (or `dnf install -y @llvm-toolset`).
- **Keep** the `update-alternatives --install /usr/bin/ld ld /usr/local/bin/ld.mold 100` shim
  (with the same revert note). It is *still required* for any link step driven by GCC 8.5 / the
  default `cc`. Only if the projects pin `CC=clang` (or `linker = "clang"` in `.cargo/config.toml`)
  and pass `-fuse-ld=mold` does the shim become redundant — and the bullseye image does not do that,
  so parity argues for keeping it.

**Warning signs:**
`Error: Unable to find a match: clang` at image build; or link times regressing (mold shim removed)
with `ld --version` reporting GNU ld instead of mold.

**Phase to address:** Toolchain install phase (clang/cmake/mold).

---

### Pitfall 3: `ninja-build` is in the disabled **PowerTools/CRB** repo, not AppStream

**What goes wrong:**
`dnf install ninja-build` fails with no-match in a default container.

**Why it happens:**
`ninja-build` (1.8.2) is in the AlmaLinux 8 **PowerTools** repo (`repo.almalinux.org/almalinux/8/PowerTools/`),
which maps to RHEL's CodeReady Builder (repo id `powertools` in AlmaLinux, `codeready-builder` in
RHEL). It is disabled by default.

**How to avoid:**
Enable the repo before installing:
```bash
dnf install -y dnf-plugins-core
dnf config-manager --set-enabled powertools    # AlmaLinux 8 repo id
dnf install -y ninja-build
```
(or `dnf --enablerepo=powertools install -y ninja-build`). Confirm the id at build time —
`dnf repolist` will show whether the id is `powertools` or `crb` depending on the base image tag.

**Warning signs:**
`No match for argument: ninja-build`.

**Phase to address:** Package-install phase.

---

### Pitfall 4: `gh` is not in any EL8 repo — and `apt install gh` has no dnf equivalent

**What goes wrong:**
`dnf install gh` fails (not in BaseOS/AppStream/EPEL). Falling back to building from source is slow
and fragile.

**Why it happens:**
GitHub CLI ships its own RPM repo (`cli.github.com/packages/rpm`). Verified `repodata` carries
`x86_64`, `aarch64`, `i386`, `armv6hl` — so both target arches are covered, but only from GitHub's
repo, never from AlmaLinux.

**How to avoid:**
```bash
dnf install -y 'dnf-command(config-manager)'
dnf config-manager --add-repo https://cli.github.com/packages/rpm/gh-cli.repo
dnf install -y gh
```
Or, to match the tarball pattern used elsewhere, download the `gh_*_linux_{amd64,arm64}.tar.gz`
release asset (Go static binary — no glibc concern).

**Warning signs:**
`No match for argument: gh`; or a gh install that unexpectedly pulls in an EPEL dependency set.

**Phase to address:** Package-install phase.

---

### Pitfall 5: Version drift breaks "identical artifacts" — GTK 3.22 vs 3.24 is the biggest gap

**What goes wrong:**
The port silently produces *different* build results because key native libraries are older on EL8
than on bullseye, even though the package names map cleanly.

**Why it happens:**
EL8 pins native library versions far below bullseye's:

| Library | bullseye | AlmaLinux 8 | Risk |
|---------|----------|-------------|------|
| GTK3 | 3.24.38 | **3.22.30** | **High** — 3.22 lacks newer GTK APIs (e.g. newer `gtk_widget_*`, Wayland/GL fixes). Projects using post-3.22 APIs will fail to compile. |
| libsecret | 0.20.4 | 0.18.6 | Medium |
| ninja | 1.10.x | 1.8.2 | Low-Medium (older `ninja` syntax is a superset, mostly fine) |
| cmake | 3.18 | 3.26.5 | None (newer — good) |
| clang | 11 | 17–21 (module) | None (newer) |
| GCC | 10.2 | 8.5 (base) | Medium — newer C++ std lib features may differ; use `gcc-toolset` if needed |
| Ruby | 2.7 | module stream (2.5/3.0/3.1/3.3) | Medium — version parity is not automatic |

**How to avoid:**
- For GTK3 specifically: verify the actual GTK APIs used by SuperGenius/SGProcessingManager against
  the 3.22 API surface *before* assuming parity. If 3.24 APIs are required, EL8 cannot satisfy them
  (no newer GTK3 in EL8) — this is a potential blocker that must be surfaced early, not at first CI run.
- For Ruby: enable an explicit stream (`dnf module enable ruby:3.1` or the stream matching bullseye's
  2.7 if needed) rather than accepting the default stream.
- Add a post-build artifact parity check (build the same sample project in both images, diff outputs).

**Warning signs:**
Compile errors referencing GTK symbols unavailable in 3.22; `ruby -v` reporting an unexpected major.

**Phase to address:** Parity/verification phase — this is the phase most likely to need deeper research.

---

### Pitfall 6: AlmaLinux 8 reaches EOL May 2029 — the "old glibc" tradeoff has a real expiry

**What goes wrong:**
The image is built on a distribution whose maintenance ends in **May 2029** (AlmaLinux 8 follows
RHEL 8's lifecycle; RHEL 8 maintenance support ends 2029-05-31). Security updates for the *base OS*
packages (glibc, OpenSSL, curl, git) stop flowing after that date, while the CI image is expected to
keep building projects.

**Why it happens:**
glibc 2.28 was deliberately chosen over AlmaLinux 9's 2.34 for broader runtime compatibility. That
choice costs ~3 years of support (AlmaLinux 9 runs to 2032).

**How to avoid:**
- Treat 2029-05 as a hard deadline for either (a) migrating the toolchain to a newer base, or
  (b) accepting frozen base packages while keeping the toolchain components (Rust/Node/JDK/mold/gh)
  self-updated from their own channels.
- Log the decision explicitly in PROJECT.md (already present as "⚠️ Revisit" on the glibc decision) and
  schedule a re-evaluation checkpoint before the EOL date.

**Warning signs:**
`dnf update` returning no newer packages; AlmaLinux announcing 8 end-of-life; CVE scanners flagging
unfixed base CVEs after 2029.

**Phase to address:** Milestone planning / roadmap-level decision (record now, act later).

---

### Pitfall 7: `apt install -y -t bullseye-backports …` has no direct dnf equivalent — repo semantics differ

**What goes wrong:**
Mechanically translating the bullseye `apt` invocation to `dnf` produces a broken or subtly different
install: the `-t bullseye-backports` target repo, `apt update`, and post-install cleanup all behave
differently.

**Why it happens:**
Specific differences that matter for this port:
- **Backports:** RHEL clones have no backports repo. Newer toolchain comes from AppStream **module
  streams** (`llvm-toolset`, `gcc-toolset`, `ruby`) and third-party repos (gh, nodesource), enabled
  individually — not from a single `-t <repo>` override.
- **Repos are disabled by default in containers:** PowerTools/CRB (ninja-build) must be explicitly
  enabled (see Pitfall 3).
- **`dnf` vs `apt update`:** `dnf makecache` / implicit update on install; cached metadata and
  downloaded RPMs must be cleaned with `dnf clean all` (and `rm -rf /var/cache/dnf`) to keep the
  image small — the `apt` equivalent (`apt-get clean; rm -rf /var/lib/apt/lists/*`) does not map 1:1.
- **GPG:** `dnf` enforces GPG signatures per-repo; third-party repos (gh, nodesource, EPEL if added)
  must import their keys or `dnf install` aborts.

**How to avoid:**
Write the package install as a list of `dnf` commands that each target the right source:
```bash
dnf install -y dnf-plugins-core
dnf config-manager --set-enabled powertools                # ninja-build
dnf module enable llvm-toolset -y && dnf install -y clang  # clang
dnf config-manager --add-repo https://cli.github.com/packages/rpm/gh-cli.repo  # gh
dnf install -y pkgconf-pkg-config git cmake wget curl libcurl-devel \
               libsecret-devel dbus dbus-daemon dbus-tools gnome-keyring \
               jq libatomic vulkan-loader vulkan-loader-devel gtk3-devel ruby
dnf clean all
```

**Warning signs:**
`No match for argument` on any package (wrong repo/name); image size ballooning from uncleaned dnf cache.

**Phase to address:** Package-install phase (single dedicated Dockerfile RUN block).

---

### Pitfall 8: dbus/gnome-keyring/libsecret exist on EL8 but need explicit sub-packages and the same machine-id setup

**What goes wrong:**
The bullseye `dbus` package pulls in the daemon + tools; on EL8 `dbus` alone does not provide
`dbus-send`/`dbus-monitor`/`dbus-run-session`, and the keyring fails silently if the machine-id and
session bus are not wired exactly as in the bullseye Dockerfile.

**Why it happens:**
- On EL8, `dbus-daemon` and `dbus-tools` are separate packages; `dbus-launch` lives in `dbus-x11`.
- `gnome-keyring` (3.28.2) and `libsecret`/`libsecret-devel` (0.18.6, BaseOS) all exist and behave
  the same as bullseye for headless `secret-tool`/keyring usage — but only if the machine-id file and
  a session bus exist.

**How to avoid:**
- Install `dbus dbus-daemon dbus-tools` (add `dbus-x11` only if `dbus-launch` is actually used).
- Keep the exact machine-id bootstrap from the bullseye Dockerfile:
  ```bash
  mkdir -p /var/lib/dbus
  cat /proc/sys/kernel/random/uuid | tr -d '-' > /var/lib/dbus/machine-id
  cp /var/lib/dbus/machine-id /etc/machine-id
  ```
- If keyring is exercised in CI, run it under `dbus-run-session` (present in `dbus-tools`).

**Warning signs:**
`gnome-keyring-daemon` failing to start with "couldn't access control socket"; `secret-tool` returning
no results; CI steps that only *sometimes* fail depending on whether a bus is running.

**Phase to address:** Package-install phase + a headless keyring smoke test in the verification phase.

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Keep `update-alternatives` mold shim (copy from bullseye) | Linker parity with bullseye; zero build-script changes | `ld` no longer tracks the distro default; hard to reason about which linker ran | Preferable — mirrors bullseye exactly |
| Use NodeSource RPM instead of official Node tarball | One-line install | Node glibc floor is governed by a rebuild, not the documented 2.28 guarantee; another repo key to manage | Only if the official tarball pattern is already in use elsewhere |
| Accept default module streams (ruby, llvm-toolset) | Fewer lines | Version can change on repo refresh; non-reproducible image | Never for ruby (version parity matters); OK for clang (any 17+ works) |
| Pin nothing (floating `dnf install`) | Simplest Dockerfile | Image is not reproducible; future repo updates silently change versions | Never for a CI base image |
| Add EPEL "just in case" | Guarantees availability | Extra repo, extra GPG key, package shadowing risk | Not needed — all required packages are in AlmaLinux AppStream/BaseOS/PowerTools + gh repo (verified) |

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| GitHub CLI (gh) | `dnf install gh` (no such package) | Add `https://cli.github.com/packages/rpm/gh-cli.repo` first |
| NodeSource (`setup_24.x`) | Assuming x86_64-only | Script validates `aarch64` + `x86_64`; uses `nodistro` repo — arm64 works |
| Adoptium JDK | Building from source or using distro OpenJDK | Use the distro-agnostic Temurin tarball exactly as the bullseye file does (aarch64 + x64) |
| rustup | Re-using the bullseye per-arch SHA256 pins blindly | The pins are arch-specific and still valid; keep the same `default-host` mapping (`x86_64`/`aarch64`) |
| mold | Downloading the `.deb` or distro package | EL8 has no mold package — keep the upstream release tarball (`x86_64`/`aarch64`) + `update-alternatives` shim |
| Vulkan | Enabling EPEL for vulkan-headers/loader | **Not required on AlmaLinux 8.10** — `vulkan-headers`, `vulkan-loader`, `vulkan-loader-devel` are in AppStream (verified) |

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Un-cleaned dnf cache in the image | Image several hundred MB larger than necessary | `dnf clean all; rm -rf /var/cache/dnf` in the same RUN layer | Always — first build already |
| Layer-ordering (package list changes invalidate toolchain cache) | Every Dockerfile tweak re-downloads Rust/JDK | Keep rarely-changing toolchain layers (Rust/JDK/mold) *after* the package layer but isolated from volatile package list edits | When the package list churns |
| `dnf` module metadata refresh on every build | Slow, non-deterministic builds | Pin module streams (`llvm-toolset`, `ruby:<stream>`) | When repos publish a new stream |

## Security Mistakes

| Mistake | Risk | Prevention |
|---------|------|------------|
| `gpgcheck=0` or `--nogpgcheck` on third-party repos (gh/nodesource) | Supply-chain: tampered packages | Import each repo's GPG key and leave gpgcheck on |
| Floating `latest` toolchain versions (Node/JDK/mold not pinned) | Unexpected breaking change in CI | Pin exact versions as the bullseye file already does (mold 2.42.0, JDK 25.0.2+10, Rust 1.87.0, Node 24.x) |
| Skipping SHA256 verification for rustup / JDK / mold tarballs | Download corruption / MITM | Keep the existing SHA256 checks (rustup is already pinned; add for JDK/mold) |
| Base image from an unofficial mirror tag | Unknown provenance | Use official `almalinux:8` (or `almalinux/8-minimal`) images |

## UX Pitfalls

*Not applicable — this is a headless CI build image with no interactive user surface. The "user" is
the CI pipeline; correctness and reproducibility replace UX concerns. The nearest analogue (covered
under Critical Pitfalls) is the *developer* surprise when a build behaves differently on EL8 than on
bullseye (Pitfall 5).*

## "Looks Done But Isn't" Checklist

- [ ] **clang:** Image builds, but `clang --version` only works in the layer that enabled `llvm-toolset` — verify it persists in the final image (module state is layer-global).
- [ ] **mold shim:** `ld --version` reports mold — verify the `update-alternatives` entry was *not* dropped during the "modernize" pass.
- [ ] **Node:** `node -v` prints v24 — verify it actually *runs* (`node -e '1+1'`), catching silent glibc mismatch.
- [ ] **JDK:** `java -version` works — verify `JAVA_HOME`/`JAVA_INCLUDE_PATH*` env vars are set (the bullseye file sets them for both shell and Docker ENV).
- [ ] **Vulkan:** `vulkaninfo` or at least `pkg-config --exists vulkan` resolves — the headers + loader are installed, but ICDs (`mesa-vulkan-drivers`) are a *separate* package and may be required for runtime.
- [ ] **gh:** `gh --version` works on **both** amd64 and arm64 — the rpm repo carries aarch64, but confirm at build time.
- [ ] **ninja:** `ninja --version` works — PowerTools repo was actually enabled (not just declared).
- [ ] **Keyring/dbus:** `dbus-run-session -- sh -c 'echo -n x | gnome-keyring-daemon --unlock'` or `secret-tool` smoke test passes.
- [ ] **Machine-id:** `/var/lib/dbus/machine-id` and `/etc/machine-id` both exist (copied from the bullseye tail).
- [ ] **Multi-arch:** the image actually builds and runs on `arm64` — not just `amd64` (module/EPEL/third-party repos all have aarch64, but this must be exercised).

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Node glibc mismatch | LOW | Reinstall Node from official tarball; re-run smoke test |
| clang "no match" | LOW | `dnf module enable llvm-toolset -y && dnf install -y clang` |
| mold shim dropped | LOW | Re-run the `update-alternatives --install /usr/bin/ld ld /usr/local/bin/ld.mold 100` block |
| ninja-build "no match" | LOW | `dnf config-manager --set-enabled powertools && dnf install -y ninja-build` |
| gh "no match" | LOW | Add `gh-cli.repo` and install |
| GTK 3.22 API gap | **HIGH** | Requires code changes in the consuming project *or* reconsidering the base image — no package fix exists on EL8 |
| Ruby wrong version | LOW-MEDIUM | `dnf module reset ruby && dnf module enable ruby:<stream>` |

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| Node 24 glibc ≥ 2.28 knife-edge | Toolchain install (Node) | `node -e` smoke test + `ldd --version` print in build log |
| clang module + `-fuse-ld=mold` / shim | Toolchain install (clang/cmake/mold) | `clang --version` ≥ 17, `ld --version` = mold |
| ninja-build in PowerTools/CRB | Package-install | `ninja --version` |
| gh needs GitHub repo | Package-install | `gh --version` on both arches |
| GTK 3.22 vs 3.24 parity | **Parity/verification** (needs deeper research) | Build sample project, diff artifacts vs bullseye |
| 2029 EOL | Milestone planning | Documented re-evaluation checkpoint |
| dnf vs apt semantics | Package-install | Single `dnf` RUN block + `dnf clean all` |
| dbus/keyring sub-packages | Package-install + verification | headless `dbus-run-session` keyring smoke test |

## Sources

Primary / authoritative (verified this session):

- Node.js minimum glibc: `nodejs/node` `BUILDING.md` (platform table + footnote [^6]) — https://github.com/nodejs/node/blob/main/BUILDING.md
- Adoptium Temurin build env / glibc floor: `adoptium/temurin-build` `FAQ.md` ("20+ | Linux/x64 | CentOS 7 | glibc 2.17"; "All | Linux (others) | CentOS 7 | glibc 2.17") and `adoptium/ci-jenkins-pipelines` `pipelines/jobs/configurations/jdk25u_pipeline_config.groovy` (`centos7_build_image`, aarch64 + x64) — https://github.com/adoptium/temurin-build/blob/master/FAQ.md
- Rust minimum glibc: `rust-lang/rust` CI Dockerfiles `src/ci/docker/host-x86_64/dist-x86_64-linux/Dockerfile` and `src/ci/docker/host-aarch64/dist-aarch64-linux/Dockerfile` ("minimum glibc 2.17", `FROM centos:7`) — https://github.com/rust-lang/rust
- mold build/portability + `-fuse-ld` driver matrix: `rui314/mold` `README.md` and `dist.sh` (Debian 9 build env; "statically linked to libstdc++"; GCC ≥ 12.1 for `-fuse-ld=mold`) — https://github.com/rui314/mold
- GitHub CLI rpm repo + arch coverage: `cli/cli` `docs/install_linux.md` and live `https://cli.github.com/packages/rpm/repodata` (aarch64, armv6hl, i386, x86_64)
- NodeSource RPM arch support: `https://rpm.nodesource.com/setup_24.x` (accepts `aarch64` + `x86_64`; `nodistro` baseurl)
- Package availability (clang module versions, gcc 8.5.0, gtk3-devel 3.22.30, gnome-keyring 3.28.2, libsecret 0.18.6, pkgconf-pkg-config, libatomic, vulkan-loader/headers in AppStream, ninja-build in PowerTools): live AlmaLinux 8 repo listings at `repo.almalinux.org/almalinux/8/{AppStream,BaseOS,PowerTools}/{x86_64,aarch64}/os/Packages/`
- AlmaLinux 8.10 release notes (aarch64 + x86_64 support; Ruby 3.3 / Git 2.43 updates): https://wiki.almalinux.org/release-notes/8.10.html
- RHEL 8 lifecycle (maintenance to 2029-05-31): Red Hat product lifecycle docs; reflected in PROJECT.md constraint "AlmaLinux 8 maintenance ends May 2029"

Confidence notes: glibc floors for JDK 25 (2.17), Node 24 (2.28), and Rust (2.17) are HIGH (primary
build configs). mold's floor is MEDIUM-HIGH (dist.sh build-env comment; not a formal support matrix).
The exact clang version that introduced `-fuse-ld=mold` (LLVM 14) is MEDIUM — but irrelevant in
practice since all EL8 llvm-toolset clang versions are 17+.

---
*Pitfalls research for: AlmaLinux 8 CI build image port*
*Researched: 2026-09-08*
