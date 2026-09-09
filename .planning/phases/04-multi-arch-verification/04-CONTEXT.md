# Phase 4: Multi-arch Verification - Context

**Gathered:** 2026-09-08
**Status:** Ready for planning

## Phase Boundary

The `almalinux-8` image is proven to build and run on `amd64` + `arm64` — and only those architectures. This phase delivers **verification + CI wiring**, not new Dockerfile layers (the toolchain is already complete through Phase 2): the buildx multi-arch push, a separate CI workflow for the Alma image, an arm64 smoke test, and the arch-clean gate. Requirements: BASE-03, PAR-03.

## Implementation Decisions

### Image Name & Tag
- **D-01:** ghcr repository name = `ghcr.io/geniusventures/almalinux-8` — mirrors the `debian-bullseye` convention and the repo dir name.
- **D-02:** Tag = `:latest` only. No versioned alias (`:8`, `:8.10`).

### CI Wiring
- **D-03:** A **separate workflow file** (e.g. `.github/workflows/ci-almalinux.yml`), NOT a second matrix entry in `ci.yml`. `ci.yml` stays bullseye-only and is not modified.
- **D-04:** The new workflow builds and pushes `ghcr.io/geniusventures/almalinux-8:latest` with `platforms: linux/amd64,linux/arm64` via buildx, mirroring `ci.yml`'s steps (login, `setup-qemu-action` with `platforms: arm64`, `setup-buildx-action`, `build-push-action`). It coexists with the bullseye job during the grace period — both images keep pushing.

### arm64 Smoke Test
- **D-05:** The arm64 run-smoke is an **in-CI QEMU step** in the new workflow: after push, `docker run --platform linux/arm64 ghcr.io/geniusventures/almalinux-8:latest …` runs the tool probes under QEMU. No manual repo script.
- **D-06:** The smoke covers the **full tool probe set** on arm64 — rustc/node/java/mold/clang/cmake/gh/pkg-config plus vulkan/gtk/libsecret probes — matching success criterion 3's "every tool" (and specifically resolving the STACK.md MEDIUM-confidence aarch64 items `gnome-keyring`, `vulkan-headers`, `gh`).

### Arch-clean Gate (BASE-03)
- **D-07:** A **grep assertion in CI** fails the build if `armhf`/`i386` appear in `almalinux-8/Dockerfile`. The invariant is already satisfied (Phase 2 D-05/D-10 deleted those branches; mold/rust/JDK blocks have 2-arm maps with a hard `exit 1` default) — this gate protects it going forward.

### Claude's Discretion
- New workflow filename (`ci-almalinux.yml` suggested), the exact smoke probe command list, and the exact grep expression for the arch-clean gate are at Claude's discretion — use the simplest approach consistent with the decisions above. No manual repo script is needed (user chose in-CI only).

## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Scope & requirements
- `.planning/ROADMAP.md` — Phase 4 success criteria (4 items): buildx manifest + both digests, no armhf/i386 branches, arm64 smoke, CI pull-by-tag resolution.
- `.planning/REQUIREMENTS.md` — BASE-03 (amd64+arm64 only), PAR-03 (buildx --platform linux/amd64,linux/arm64) definitions.

### CI source of truth (mirror, do not modify)
- `.github/workflows/ci.yml` — the bullseye-only workflow; its login/QEMU/buildx/build-push steps are the template for the new workflow. **Not modified in Phase 4.**

### Target image
- `almalinux-8/Dockerfile` — current state; already arch-clean (mold/rust/JDK blocks each have `x86_64`/`aarch64` maps + `exit 1` default). The in-image verification chains (steps 9 + 10) run on arm64 under buildx.

### Prior context & research
- `.planning/phases/03-parity-verification/03-CONTEXT.md` — D-02: Phase 4 owns the Alma multi-arch buildx push; ci.yml was deliberately untouched in Phase 3.
- `.planning/phases/02-toolchain-install/02-CONTEXT.md` — D-05/D-10: armhf/i386 branches already deleted; 2-arm maps with hard `exit 1` defaults.
- `.planning/research/STACK.md` — arm64 flags: `gnome-keyring` + `vulkan-headers` aarch64 availability are the two MEDIUM-confidence items to validate on arm64.
- `debian-bullseye/Dockerfile` — the analog image (grace period: both images push in parallel).
- `.planning/PROJECT.md` — LIFE-01 deferred (remove debian-bullseye after validation); the separate workflow supports this cleanly.

## Existing Code Insights

### Reusable Assets
- `ci.yml` job steps (docker/login-action, setup-qemu-action with `platforms: arm64`, setup-buildx-action, build-push-action with `platforms: linux/amd64,linux/arm64`) — mirror these verbatim in the new workflow.
- `almalinux-8/Dockerfile` in-image verification chains — already exercised on arm64 by buildx; the post-push smoke is a runtime re-check, not a replacement.

### Established Patterns
- buildx multi-arch via `platforms: linux/amd64,linux/arm64` (already the bullseye convention).
- Verification via version-string probes (`--version`, `pkg-config --exists`) as fail-fast gates.

### Integration Points
- New file `.github/workflows/ci-almalinux.yml` — the only new artifact. `ci.yml` is untouched.
- `ghcr.io/geniusventures` registry (packages: write permission already configured).

## Specific Ideas

- "Eventually bullseye probably gets removed" — the separate workflow is chosen specifically so removing `debian-bullseye` (LIFE-01) is a clean one-file deletion, not a matrix edit.

## Deferred Ideas

- **Remove `debian-bullseye`** (LIFE-01) — after the Alma image is validated in CI; the separate workflow makes this a clean deletion.

---

*Phase: 4-Multi-arch Verification*
*Context gathered: 2026-09-08*
