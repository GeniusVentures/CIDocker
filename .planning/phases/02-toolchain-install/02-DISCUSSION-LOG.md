# Phase 2: Toolchain Install - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-09-08
**Phase:** 2-Toolchain Install
**Areas discussed:** Node install source, Rust profile & components, ENV contract fidelity, Arch detection shape

---

## Node install source (TOOL-02)

| Option | Description | Selected |
|--------|-------------|----------|
| NodeSource rpm (`dnf install nodejs`) | Repo already enabled in Phase 1; rolling 24.x updated via dnf. Matches STACK.md. Built on RHEL8 so glibc 2.28 is satisfied. | ✓ |
| Official nodejs.org tarball | Pinned exact 24.x version + SHA256 verify; self-contained, no dnf deps. STATE.md flags this as 'safest' for the glibc 2.28 floor. | |
| You decide | — | |

**User's choice:** NodeSource rpm (`dnf install nodejs`)
**Notes:** None.

### Node version pinning (follow-up)

| Option | Description | Selected |
|--------|-------------|----------|
| Rolling 24.x (`dnf install nodejs`) | Parity with bullseye (which also leaves 24.x rolling). PAR-01 only requires 'Node 24', not an exact patch. | ✓ |
| Pin exact (e.g. nodejs-24.x.y) | Fully reproducible build. Deviates from bullseye's rolling behavior; breaks when NodeSource drops old patches. | |
| You decide | — | |

**User's choice:** Rolling 24.x
**Notes:** None.

---

## Rust profile & components (TOOL-03)

| Option | Description | Selected |
|--------|-------------|----------|
| minimal (parity) | Byte-for-byte parity with bullseye: rustc + cargo + rust-std only. No clippy/rustfmt. | ✓ |
| default (adds clippy/rustfmt) | Adds rustfmt + clippy for lint/format CI gates. Slightly larger image; deviates from bullseye. | |
| You decide | — | |

**User's choice:** minimal (parity)
**Notes:** None.

---

## ENV contract fidelity (TOOL-05)

| Option | Description | Selected |
|--------|-------------|----------|
| Byte-for-byte parity | Mirror bullseye exactly: PATH written literally, all JAVA_* vars included. Deterministic and matches the 'env contract' success criterion verbatim. | ✓ |
| Adapted (append :$PATH) | Append :$PATH in the final block too, preserving any EL8 base defaults. Deviates from bullseye's final PATH string. | |
| You decide | — | |

**User's choice:** Byte-for-byte parity
**Notes:** None.

---

## Arch detection shape (TOOL-03/TOOL-04)

| Option | Description | Selected |
|--------|-------------|----------|
| Per-block `uname -m` case maps | Mirror the analog exactly — each block independently computes `uname -m` and maps it. Self-contained blocks; works under buildx qemu emulation. | ✓ |
| BuildKit `ARG TARGETARCH` | Use Docker's pre-defined amd64/arm64 ARG once. Idiomatic for buildx, but deviates from the analog's runtime detection. | |
| Compute once, share via ENV | Set a shared ARCH env from `uname -m` once; each block maps from it. DRYer but adds a cross-block dependency. | |

**User's choice:** Per-block `uname -m` case maps
**Notes:** Hard `exit 1` default for unsupported arches retained (BASE-03).

---

## Claude's Discretion

None — every area was decided explicitly by the user.

## Deferred Ideas

None — discussion stayed within phase scope.
