# Phase 3: Parity & Verification - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-09-09
**Phase:** 3-Parity & Verification
**Areas discussed:** Verification harness, Sample build bar, GTK gap method, Clang/Ruby drift bar

---

## Verification Harness

| Option | Description | Selected |
|--------|-------------|----------|
| Repo script + CI job | Versioned `verify-parity.sh` invoked manually and from ci.yml | ✓ |
| CI workflow job only | Extend ci.yml with a parity job; automated, not local | |
| Documented runbook only | Manual step-by-step runbook; least durable | |

**User's choice:** Repo script + CI job (later narrowed — see below).

**Version matrix bar:**

| Option | Description | Selected |
|--------|-------------|----------|
| Compare at stated majors | Rust 1.87.0, Node 24.x, JDK 25.x, mold 2.42.0 | ✓ |
| Pin Node patch to bullseye | Force byte-identical Node versions | |
| Report, don't fail | Print matrices, only fail on majors | |

**User's choice:** Compare at stated majors (Node patch may differ; no pin).

**CI gating:**

| Option | Description | Selected |
|--------|-------------|----------|
| Blocking gate | Parity job fails CI on mismatch | |
| Advisory only | Runs, reports, never fails | |
| Manual only | Script run by hand; CI unchanged | ✓ |

**User's choice:** Manual only — parity script run by hand for this phase's sign-off; CI not modified in Phase 3 (Phase 4 owns CI/multi-arch).

**Notes:** The first answer ("Repo script + CI job") was superseded by the gating answer ("Manual only"). Net decision: versioned repo script, run manually; CI untouched.

---

## Sample Build Bar

| Option | Description | Selected |
|--------|-------------|----------|
| The GTK-using project | Build the real project that consumes GTK | |
| Both projects | Build SuperGenius + SGProcessingManager | |
| Minimal smoke crate | In-repo fixture instead of real projects | ✓ |

**User's choice:** Minimal fixture. Free text: "We can't really build SuperGenius or SGProcessingManager without first compiling thirdparty, which is frankly a large mono repo. Lets do something minimal, and i'll later create a branch on thirdparty CI pointing to this new docker image, that will be the final final verification."

**Fixture coverage:**

| Option | Description | Selected |
|--------|-------------|----------|
| Rust + mold + GTK | Rust crate with a GTK header via build script | |
| Rust + mold only | Rust crate that links via mold | |
| One artifact per tool | Probes for each tool | |

**User's choice (free text):** "I honestly don't know that we ever use a GTK header. We build mostly C++ code, a small bit of rust, and even flutter code (flutter is checked out in thirdparty so it isn't part of the docker image). Node is more often used as a tool rather than running nodejs itself. Just make sure clang and rust work and anything else that is easy."

**Notes:** Fixture = C++ file (clang + mold) + small Rust crate; trivial Node/Java probes if easy. Flutter out of scope. Equivalence is behavioral, not byte-identical.

---

## GTK Gap Method

| Option | Description | Selected |
|--------|-------------|----------|
| Compile probe + grep usage | Compile against gtk3-devel + grep consuming code for GTK includes | ✓ |
| Compile probe only | Prove headers/libs resolve; skip code grep | |
| Documented accept-risk | Record gap as accepted risk, no probe | |

**User's choice:** Compile probe + grep usage.

**Notes:** GTK headers may not be used at all — lowers the flagged top risk. Grep target is the consuming monorepo at `w:\gnus\GeniusNetwork`.

---

## Clang/Ruby Drift Bar

| Option | Description | Selected |
|--------|-------------|----------|
| Compile + run on both | Behavioral equivalence, warnings recorded | |
| Behavioral + characterize | Also diff warnings/artifact sizes | |
| Documented accept-risk | Record 11→17 as accepted drift | ✓ |

**User's choice (after asking "What is the situation with clang?"):** Documented accept-risk. clang 11→17 is unavoidable on EL8 (no clang 11 package; source build is forbidden fragility). Behavioral confirmation is the thirdparty CI final verification.

**Ruby drift:**

| Option | Description | Selected |
|--------|-------------|----------|
| Documented + cheap probe | `ruby --version` + trivial `ruby -e` on both | ✓ |
| Documented accept-risk only | Record drift, no probe | |
| Active behavioral check | Exercise wallet-core now (needs thirdparty) | |

**User's choice:** Documented + cheap probe.

**Notes:** Ruby is used by `wallet-core` (extent unknown). Drift is 2.7 (bullseye) → 3.1 (EL8; no 2.7 stream exists on EL8). Behavioral confirmation deferred to thirdparty CI.

---

## Claude's Discretion

- Script name/location (`almalinux-8/verify-parity.sh`).
- Whether the script pulls the frozen bullseye image from ghcr or builds it locally.
- Exact fixture layout.

## Deferred Ideas

- **Final verification** — user creates a branch on thirdparty CI pointing at the new image; builds SuperGenius/SGProcessingManager/wallet-core there (the true sign-off, after this phase).
- **wallet-core Ruby behavioral check** — deferred to the thirdparty CI final verification.
