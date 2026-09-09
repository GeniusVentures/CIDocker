# Phase 4: Multi-arch Verification - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-09-08
**Phase:** 4-Multi-arch Verification
**Areas discussed:** Image name & tag, CI wiring, arm64 smoke test, Arch-clean gate

---

## Image name & tag

| Option | Description | Selected |
|--------|-------------|----------|
| almalinux-8 | ghcr.io/geniusventures/almalinux-8 — mirrors debian-bullseye and repo dir name | ✓ |
| cidocker-almalinux-8 | Namespaces the image under a cidocker prefix | |
| almalinux8 | No hyphen variant | |

**User's choice:** `almalinux-8`
**Notes:** Current CI pushes `ghcr.io/geniusventures/debian-bullseye:latest` — naming mirrors that convention.

| Option | Description | Selected |
|--------|-------------|----------|
| :latest only | Single rolling tag — exact mirror of debian-bullseye convention | ✓ |
| :latest + :8 | Rolling tag plus a :8 alias so consumers can pin the major | |
| :latest + :8.10 | Pin to :8.10 in addition to :latest | |

**User's choice:** `:latest` only
**Notes:** No versioned alias wanted.

## CI wiring

| Option | Description | Selected |
|--------|-------------|----------|
| Second matrix entry | Add {context: almalinux-8, image: almalinux-8} to the existing matrix | |
| Separate job | A separate docker job for Alma — cleaner isolation but duplicates setup | |
| Separate workflow | A second workflow file — fully independent but diverges the CI surface | |

**User's choice:** Free text — "Separate workflow, eventually bullseye probably gets removed so that makes it easy."
**Notes:** Chosen specifically so removing `debian-bullseye` later (LIFE-01) is a clean one-file deletion.

## arm64 smoke test

| Option | Description | Selected |
|--------|-------------|----------|
| In-CI QEMU step | CI step in the new workflow: docker run --platform linux/arm64 under QEMU — automated sign-off | ✓ |
| Manual script | verify-multiarch.sh run manually, mirroring Phase 3's verify-parity.sh | |
| Both | CI minimal probe + manual full sweep | |

**User's choice:** In-CI QEMU step
**Notes:** QEMU (setup-qemu-action) is already in the repo's CI.

| Option | Description | Selected |
|--------|-------------|----------|
| Full probe set | rustc/node/java/mold/clang/cmake/gh/pkg-config + vulkan/gtk/libsecret on arm64 | ✓ |
| Flagged trio + core | Only gnome-keyring/vulkan-headers/gh plus rustc/node/java/mold | |
| Minimal arch check | Just confirm arm64 pull resolves + uname -m = aarch64 | |

**User's choice:** Full probe set
**Notes:** buildx already runs the in-image verification chains on arm64 during the build; the post-push smoke is the runtime sign-off.

## Arch-clean gate

| Option | Description | Selected |
|--------|-------------|----------|
| Grep assertion in CI | CI step greps the Dockerfile for armhf\|i386 and fails if found | ✓ |
| Document only | No automated check — document existing exit-1 defaults | |
| Grep + inline comment | Grep assertion in CI plus a Dockerfile comment marking the invariant | |

**User's choice:** Grep assertion in CI
**Notes:** The Dockerfile is already arch-clean (Phase 2); this gate protects the invariant going forward.

## Claude's Discretion

- New workflow filename (`ci-almalinux.yml` suggested)
- Exact smoke probe command list
- Exact grep expression for the arch-clean gate

## Deferred Ideas

- Remove `debian-bullseye` (LIFE-01) — after the Alma image is validated in CI; the separate workflow makes this a clean deletion.
