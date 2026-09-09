# Phase 3: Parity & Verification - Context

**Gathered:** 2026-09-09
**Status:** Ready for planning

## Phase Boundary

The `almalinux-8` image is verified to behave identically to `debian-bullseye` for the consuming builds. This phase produces **verification evidence** — not more Dockerfile layers: a side-by-side toolchain version matrix, a minimal representative sample build, the GTK 3.22-vs-3.24 gap check, and clang/Ruby drift documentation. Requirements: PAR-01, PAR-02.

## Implementation Decisions

### Verification Harness
- **D-01:** Deliver a versioned repo script `almalinux-8/verify-parity.sh` that runs both images side-by-side, diffs the version matrix, and runs the sample build. It is run **manually** for this phase's sign-off.
- **D-02:** CI is **not** modified in Phase 3. `.github/workflows/ci.yml` keeps building/pushing only `debian-bullseye`. Phase 4 owns the Alma multi-arch buildx push.
- **D-03:** Version-matrix comparison bar = stated majors only: Rust 1.87.0, Node 24.x, JDK 25.x, mold 2.42.0. Node is rolling, so Node patch versions are allowed to differ — do **not** pin Node to the frozen bullseye patch.

### Sample Build
- **D-04:** The sample build is a **minimal in-repo fixture**, not the real consuming projects (building SuperGenius/SGProcessingManager requires compiling the thirdparty monorepo first — out of scope here).
- **D-05:** The fixture covers a **C++ file (clang + mold link)** + a **small Rust crate**; trivial Node/Java probes are "nice to have, if easy." Flutter is out of scope (checked out in thirdparty, not in the image).
- **D-06:** Equivalence bar = **behavioral**: the fixture builds and runs with identical behavior/output on both images. **Not** byte-identical (clang 11→17 makes that implausible).

### GTK Gap (PAR-02)
- **D-07:** Verify non-blocking by (a) compiling a tiny probe against EL8 `gtk3-devel` to prove headers/libs resolve, and (b) grepping the consuming monorepo for GTK includes to confirm they are unused. The consuming code is mostly C++ with likely no GTK header usage.

### Clang/Ruby Drift
- **D-08:** Clang 11→17 drift: **documented accept-risk** — record as known/accepted drift, with no active warning/artifact diffing. clang cannot be pinned back to 11 on EL8 (no package; source build is forbidden fragility).
- **D-09:** Ruby drift 2.7 (bullseye) → 3.1 (EL8): **documented + cheap probe** — `ruby --version` and a trivial `ruby -e` on both images. `wallet-core` is the known consumer (extent unknown); behavioral confirmation is deferred to the thirdparty CI final verification. No 2.7 stream exists on EL8.

### Claude's Discretion
- Script name/location (`almalinux-8/verify-parity.sh`), whether the script pulls the frozen bullseye image from ghcr vs builds it locally, and the exact fixture layout are at Claude's discretion — use the simplest approach consistent with the decisions above.

## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Parity source of truth
- `debian-bullseye/Dockerfile` — the authoritative analog; the toolchain blocks and env contract that parity is measured against.

### Target image (Phases 1–2 complete)
- `almalinux-8/Dockerfile` — current state; in-image verification chain ends at step 10. Phase 3 adds verification **outside** this file.

### Prior context & research
- `.planning/phases/02-toolchain-install/02-CONTEXT.md` — locked Phase 2 decisions (D-01…D-10); byte-for-byte parity principle.
- `.planning/phases/02-toolchain-install/02-RESEARCH.md` — toolchain install recipe + integrity posture (mold via TLS, rustup SHA256-pinned, Temurin via TLS).
- `.planning/phases/02-toolchain-install/02-VERIFICATION.md` — established verification convention (in-image chain + `docker run` probes).
- `.planning/phases/01-base-package-install/01-RESEARCH.md` — ruby:3.1 module decision (Q1).

### CI & requirements
- `.github/workflows/ci.yml` — current CI: builds/pushes only `debian-bullseye` (amd64+arm64 via buildx). Not modified in Phase 3.
- `.planning/ROADMAP.md` — Phase 3 success criteria (4 items).
- `.planning/REQUIREMENTS.md` — PAR-01, PAR-02 definitions.

## Existing Code Insights

### Reusable Assets
- `debian-bullseye/Dockerfile` — the frozen image to compare against.
- `almalinux-8/Dockerfile` — already carries the full toolchain; its in-image verification chain (step 10) is the baseline.
- The consuming monorepo at `w:\gnus\GeniusNetwork` — grep target for GTK includes (SuperGenius, SGProcessingManager, wallet-core).

### Established Patterns
- Verification convention: version-string probes (`--version`, `pkg-config --exists`) as fail-fast gates.
- Heredoc `RUN <<EOF` + `set -eux` for multi-command blocks; version pins as shell vars (not `ARG`s).

### Integration Points
- `almalinux-8/verify-parity.sh` is a **new standalone script** — the first repo artifact outside the two Dockerfiles.
- CI (`ci.yml`) is **not** a Phase 3 integration point (unchanged).

## Specific Ideas

- The user's "final final verification" is a branch on thirdparty CI pointing at the new image — this happens **after** this phase and is not part of its scope.

## Deferred Ideas

- **Final verification** — user creates a branch on thirdparty CI pointing at the new image; builds SuperGenius/SGProcessingManager/wallet-core there (the true sign-off).
- **wallet-core Ruby behavioral check** — deferred to the thirdparty CI final verification (wallet-core is the known Ruby consumer; extent unknown).

---

*Phase: 3-Parity & Verification*
*Context gathered: 2026-09-09*
