# Phase 3: Parity & Verification - Pattern Map

**Mapped:** 2026-09-08
**Files analyzed:** 5 (new) + 3 (locked-out, NOT modified)
**Analogs found:** 1 / 5 (fixtures have no in-repo source analog)

## Scope Summary

Phase 3 produces **verification evidence, not image layers** (D-01…D-09). The deliverables
are one standalone bash harness plus a minimal in-repo fixture, all colocated under
`almalinux-8/`. Three files are **locked out** by decision D-02 and the phase boundary:

| File | Phase 3 disposition |
|------|---------------------|
| `almalinux-8/Dockerfile` | NOT modified (complete since Phase 2) |
| `debian-bullseye/Dockerfile` | NOT modified (parity source of truth) |
| `.github/workflows/ci.yml` | NOT modified (D-02; Phase 4 owns CI) |

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `almalinux-8/verify-parity.sh` | script / verification harness | batch orchestration (host-side: build → pull → probe → diff) | `almalinux-8/Dockerfile` step 10 verification chain (lines 215-229) | role-match |
| `almalinux-8/fixture/cpp/main.cpp` | test fixture source (C++) | transform (compile + run → fixed-string stdout) | none in repo | no-analog |
| `almalinux-8/fixture/rust/Cargo.toml` | test fixture config (crate manifest) | build manifest | none in repo | no-analog |
| `almalinux-8/fixture/rust/src/main.rs` | test fixture source (Rust) | transform (compile + run → fixed-string stdout) | none in repo | no-analog |
| `almalinux-8/fixture/gtk_probe.c` | test fixture source (C, compile-only) | transform (compile + run-safe exit code) | none in repo | no-analog |

> Optional derived artifact at planner discretion (Open Question 2 in RESEARCH.md): a
> committed `03-PARITY-REPORT.md` drift record. It is a GSD markdown artifact (like
> `02-VERIFICATION.md`), not code — see "Shared Patterns → Drift documentation" below.

**Key classification note:** `verify-parity.sh` is the **first standalone repo script**
outside the two Dockerfiles. Its "role" has no exact in-repo twin; the closest analog by
*data flow* (fail-fast version probing, stateless `docker run --rm <img> <cmd>` probes,
`set -eux` hygiene) is the Dockerfile heredoc verification chain. The fixture `.cpp/.rs/.c`
files have **no codebase analog** — this repo has never contained application source — so
the planner must use the complete, validated code examples already in
`03-RESEARCH.md` ("Code Examples" section) for those.

---

## Pattern Assignments

### `almalinux-8/verify-parity.sh` (script, batch orchestration)

**Analog 1:** `almalinux-8/Dockerfile` — step 10 verification chain (lines 215-229) for
fail-fast probe style and `set -eux` hygiene.

**Analog 2:** `debian-bullseye/Dockerfile` — mold block (lines 38-62) for the version-pin
shell-var convention and the `case` arch map.

**Analog 3:** `.github/workflows/ci.yml` (lines 40-46) for the image tag/buildx pattern
(read-only — CI itself is NOT modified).

**Fail-fast probe pattern** (`almalinux-8/Dockerfile` lines 215-229):

```dockerfile
# 10) Phase 2 verification chain — fails the build if any success criterion is unmet.
RUN <<EOF

set -eux

ld --version | grep -q 'mold 2.42.0'
node --version | grep -q '^v24\.'
node -e 'process.exit(0)'
rustc --version | grep -q '1.87.0'
java -version 2>&1 | grep -q 'Temurin-25'
test "$(git config --system --get safe.directory)" = '*'
test -s /var/lib/dbus/machine-id
cmp -s /var/lib/dbus/machine-id /etc/machine-id
echo "JAVA_HOME=$JAVA_HOME JDK_HOME=$JDK_HOME RUSTUP_HOME=$RUSTUP_HOME CARGO_HOME=$CARGO_HOME"

EOF
```

**How the harness maps to this:** the script's Stage 1 matrix hard gate reuses the exact
four probes `ld --version | grep -q 'mold 2.42.0'`, `node --version | grep -q '^v24\.'`,
`rustc --version | grep -q '1.87.0'`, `java -version 2>&1 | grep -q 'Temurin-25'`
(D-03 bar), but wrapped in `docker run --rm <img> bash -c '…'` and compared across the
two images at the stated-major level instead of a single-image `grep -q`.

**Version-pin shell-var pattern** (`debian-bullseye/Dockerfile` lines 48-52):

```dockerfile
moldVersion="2.42.0"; \
moldArchive="mold-${moldVersion}-${moldArch}-linux.tar.gz"; \
cd /tmp; \
wget -q "https://github.com/rui314/mold/releases/download/v${moldVersion}/${moldArchive}"; \
```

**How the harness maps to this:** the harness does not re-derive these pins — it *compares*
them. The D-03 majors (Rust 1.87.0, Node 24.x, JDK 25.x, mold 2.42.0) are constants in the
script, mirroring the pins above. Node is compared at major only (rolling, D-03).

**Arch-map `case` pattern** (`almalinux-8/Dockerfile` lines 112-116):

```dockerfile
case "$(uname -m)" in \
    x86_64) moldArch='x86_64' ;; \
    aarch64) moldArch='aarch64' ;; \
    *) echo >&2 "unsupported architecture for mold: $(uname -m)"; exit 1 ;; \
esac; \
```

**How the harness maps to this:** the harness runs on the host, not in a build layer, so it
does **not** need an arch `case` — the Dockerfiles already handle arch. But it inherits the
same fail-fast idiom: unsupported/unreachable state → `echo >&2 …; exit 1`.

**Image acquisition pattern** (`.github/workflows/ci.yml` lines 40-46, read-only reference):

```yaml
      - name: Build and push
        uses: docker/build-push-action@v7
        with:
          context: ${{matrix.context}}
          platforms: linux/amd64, linux/arm64
          push: true
          tags: ghcr.io/geniusventures/${{matrix.image}}:latest
```

**How the harness maps to this:** the script pulls the frozen comparison image from the
exact tag CI pushes — `ghcr.io/geniusventures/debian-bullseye:latest` (env-var default
`BULLSEYE_IMAGE`). The Alma image is built locally (`docker build -t cidocker-almalinux-8:parity -f
almalinux-8/Dockerfile .`) because no ghcr tag exists for it yet. CI is NOT touched.

**`docker run --rm <img> <cmd>` probe convention** (from `02-VERIFICATION.md`
"Behavioral Spot-Checks", which documents the established convention):

```text
docker run --rm cidocker-almalinux-8:phase2 ld --version      # → mold 2.42.0
docker run --rm cidocker-almalinux-8:phase2 node --version    # → v24.20.0
docker run --rm cidocker-almalinux-8:phase2 rustc --version   # → rustc 1.87.0
docker run --rm cidocker-almalinux-8:phase2 java -version     # → Temurin 25.0.2+10
```

**How the harness maps to this:** every probe in `verify-parity.sh` is a throwaway
`docker run --rm <img> <cmd>`; no state persists between probes (RESEARCH.md Pattern 1).
The fixture is mounted read-only (`-v "$SCRIPT_DIR/fixture:/src:ro"`) and writes compiled
artifacts to `/tmp` (Pitfall 4).

**Shell hygiene to copy:**
- `#!/usr/bin/env bash` + `set -euo pipefail` (the Dockerfile `set -eux` translated to a
  standalone script; `-u`/`-o pipefail` are script-only additions, `-x` is intentionally
  omitted so the manual-run evidence output stays readable).
- `SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"` — first use in repo; needed
  because the script must locate `fixture/` and `Dockerfile` relative to itself.
- Pre-flight `docker info` guard with a clear message + `exit 1` (Pitfall 3) — mirrors the
  fail-fast `grep -q` + `set -e` convention, applied to an external dependency instead of a
  package probe.

---

### `almalinux-8/fixture/cpp/main.cpp` (fixture source, transform) — NO ANALOG

No C++ source has ever existed in this repo. Use the complete, validated example in
`03-RESEARCH.md` ("Code Examples" → `fixture/cpp/main.cpp`). Two constraints from the
research must be honored verbatim:

- **Fixed-string output** (`cpp-ok 15`), never an embedded version string (D-06, Pitfall 2).
- **Plain `clang++`** — do NOT pass `-fuse-ld=mold`; bullseye clang 11 predates it
  (RESEARCH.md Pattern 4 / Pitfall 1). mold is selected via the `update-alternatives` ld
  shim, which both Dockerfiles register (`debian-bullseye/Dockerfile` line 58,
  `almalinux-8/Dockerfile` line 124).

### `almalinux-8/fixture/rust/Cargo.toml` (fixture config) — NO ANALOG

No Rust manifest has ever existed in this repo. Use `03-RESEARCH.md` ("Code Examples") —
a std-only crate (`[dependencies]` absent) so `cargo run` needs no crates.io fetch.

### `almalinux-8/fixture/rust/src/main.rs` (fixture source) — NO ANALOG

Use `03-RESEARCH.md` ("Code Examples") — prints the fixed string `rust-ok 15`. Honor
Pitfall 4: mount read-only + `CARGO_TARGET_DIR=/tmp/cargo_target` so `target/` never
lands in the repo.

### `almalinux-8/fixture/gtk_probe.c` (fixture source, compile-only) — NO ANALOG

Use `03-RESEARCH.md` ("Code Examples") — `#include <gtk/gtk.h>` + `gtk_get_major_version()`
(display-free accessor). Compile-only/run-safe; do NOT call `gtk_init` (Pitfall 5). The
compile command reuses the EL8 `pkg-config --exists gtk+-3.0` probe convention already in
`almalinux-8/Dockerfile` line 96, extended with `--cflags --libs` for a real compile.

---

## Shared Patterns

### Fail-fast version probe (apply to: `verify-parity.sh` Stage 1)

**Source:** `almalinux-8/Dockerfile` step 10, lines 219-223.

```dockerfile
ld --version | grep -q 'mold 2.42.0'
node --version | grep -q '^v24\.'
rustc --version | grep -q '1.87.0'
java -version 2>&1 | grep -q 'Temurin-25'
```

The harness wraps each in `docker run --rm <img> bash -c '…'`, collects the four majors
into a matrix, and hard-gates equality across the two images (D-03). Everything else
(clang, cmake, ruby, gtk, glibc) is **reported, not gated** (D-08/D-09).

### `docker run --rm` throwaway probe (apply to: all harness stages)

**Source:** `02-VERIFICATION.md` Behavioral Spot-Checks (convention) + `ci.yml` tags.

```text
docker run --rm cidocker-almalinux-8:phase2 ld --version
```

Every check is stateless — the image is the subject, the host script is the orchestrator
(RESEARCH.md Pattern 1). The two image refs are centralized as env-var-overridable
defaults (`ALMA_IMAGE`, `BULLSEYE_IMAGE`), mirroring the way the Dockerfiles centralize
version pins as shell vars.

### Shell hygiene: `set -eux` + fail-fast (apply to: `verify-parity.sh`)

**Source:** every heredoc in both Dockerfiles, e.g. `almalinux-8/Dockerfile` line 217
(`set -eux`) and `debian-bullseye/Dockerfile` line 40 (`set -eux`). The standalone script
uses `set -euo pipefail` — the script equivalent of the same fail-fast contract.

### Arch `case` map with hard `exit 1` default (informational — host script does not need it)

**Source:** `almalinux-8/Dockerfile` lines 112-116; `debian-bullseye/Dockerfile` lines
41-46. The harness does not add a new arch map (the Dockerfiles own arch selection); it
inherits the fail-fast idiom only.

### Drift documentation (D-08/D-09) — markdown record pattern

**Source:** `02-VERIFICATION.md` (frontmatter + goal-achievement tables). If the planner
elects to commit durable drift evidence (RESEARCH.md Open Question 2), the record follows
the GSD phase-artifact style: a `03-PARITY-REPORT.md` in
`.planning/phases/03-parity-verification/` with a frontmatter block and an
"Observable Truths" table, not freeform prose. Clang 11→17 is **documented accept-risk**
(no active diffing); Ruby 2.7→3.1 is documented + probed via `ruby --version` and a trivial
`ruby -e` on both images.

---

## No Analog Found

Files with no close match in the codebase (planner should use `03-RESEARCH.md` "Code
Examples" verbatim — they are complete and validated against the clang-11/Node-patch/GTK
pitfalls):

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| `almalinux-8/fixture/cpp/main.cpp` | fixture source | transform | Repo has never contained C++ application source |
| `almalinux-8/fixture/rust/Cargo.toml` | fixture config | build manifest | No Rust crate exists in repo |
| `almalinux-8/fixture/rust/src/main.rs` | fixture source | transform | No Rust source exists in repo |
| `almalinux-8/fixture/gtk_probe.c` | fixture source | compile-only transform | No C source exists in repo |

The fixture design constraints (fixed-string output, no `-fuse-ld=mold`, read-only mount,
std-only crate, display-free GTK probe) are all **derived from the Dockerfile patterns
above** (the mold shim and the `grep -q` probes), so even the "no analog" files are
constrained by the same established conventions.

## Metadata

**Analog search scope:** `debian-bullseye/Dockerfile`, `almalinux-8/Dockerfile`,
`.github/workflows/ci.yml`, `.planning/phases/02-toolchain-install/02-VERIFICATION.md`,
`.planning/phases/02-toolchain-install/02-PATTERNS.md` (format reference).
**Files scanned:** 3 code files + 2 phase docs.
**Pattern extraction date:** 2026-09-08
