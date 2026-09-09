# Phase 4: Multi-arch Verification - Pattern Map

**Mapped:** 2026-09-09
**Files analyzed:** 1 new / 0 modified
**Analogs found:** 3 / 1 (one file, three contributing analogs)

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `.github/workflows/ci-almalinux.yml` | config (GitHub Actions workflow) | batch (checkout → gate → build/push → inspect → pull → smoke) | `.github/workflows/ci.yml` | exact |

This phase's entire deliverable is **one new file** (D-03, D-05: no manual repo script; `ci.yml` is explicitly not modified). The Dockerfile and `verify-parity.sh` are read-only sources of probe strings and the arch-clean pattern — not modified in this phase.

---

## Pattern Assignments

### `.github/workflows/ci-almalinux.yml` (config, batch)

**Primary analog:** `.github/workflows/ci.yml` — the bullseye-only workflow whose five core steps are mirrored verbatim (D-04), then three verification steps are appended.

**Workflow skeleton + permissions pattern** (`ci.yml` lines 1-12):
```yaml
name: ci

permissions:
  contents: read
  packages: write

on:
  push:
  workflow_dispatch:
```

Copy this structure into the new file, renaming `name: ci-almalinux`. Keep `permissions: { contents: read, packages: write }` — the `packages: write` is required for the ghcr.io push (RESEARCH Anti-Patterns). **Do NOT copy `env: GH_TOKEN: ${{ secrets.GNUS_TOKEN_1 }}`** — no step in either workflow consumes it (RESEARCH Pitfall 5).

**Step sequence to mirror verbatim** (`ci.yml` lines 22-46):
```yaml
      - name: Checkout
        uses: actions/checkout@v6

      - name: Login to Docker Hub
        uses: docker/login-action@v4
        with:
          registry: ghcr.io
          username: ${{github.actor}}
          password: ${{secrets.GITHUB_TOKEN}}

      - name: Set up QEMU
        uses: docker/setup-qemu-action@v4
        with:
          platforms: arm64

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v4

      - name: Build and push
        uses: docker/build-push-action@v7
        with:
          context: ${{matrix.context}}
          platforms: linux/amd64, linux/arm64
          push: true
          tags: ghcr.io/geniusventures/${{matrix.image}}:latest
```

Ordering is load-bearing: QEMU must precede buildx and any `docker run --platform linux/arm64` (RESEARCH Pitfall 2). The new workflow drops the `strategy.matrix` (single image, D-03) and hardcodes:
- `context: almalinux-8`
- `tags: ghcr.io/geniusventures/almalinux-8:latest` (D-01/D-02 — `:latest` only, no versioned alias)

**Arch-clean gate (BASE-03, D-07) — grep token form** (pattern source: `almalinux-8/Dockerfile` case labels):
The gate must use the **case-label token form**, not a bare `armhf|i386` grep (RESEARCH Pitfall 1 — a bare grep matches the Dockerfile comments on lines 143 and 165):
```yaml
      - name: Arch-clean gate (BASE-03)
        run: |
          if grep -nE '(armhf|i386)\)|armv7-unknown|i686-unknown' almalinux-8/Dockerfile; then
            echo "::error::32-bit architecture reference found in almalinux-8/Dockerfile"
            exit 1
          fi
          test "$(grep -cE 'exit 1' almalinux-8/Dockerfile)" -ge 3
```

The positive `exit 1` assertion is verified against the current Dockerfile — the three hard-default blocks are the mold map (line 115), the Rust map (line 152), and the JDK map (line 175):
```dockerfile
    x86_64) moldArch='x86_64' ;; \
    aarch64) moldArch='aarch64' ;; \
    *) echo >&2 "unsupported architecture for mold: $(uname -m)"; exit 1 ;; \
```

**Multi-arch manifest verification (PAR-03)** — `docker buildx imagetools inspect --raw` (no jq dependency):
```yaml
      - name: Verify multi-arch manifest (PAR-03)
        run: |
          docker buildx imagetools inspect --raw ghcr.io/geniusventures/almalinux-8:latest > /tmp/manifest.json
          grep -q '"architecture":"amd64"' /tmp/manifest.json
          grep -q '"architecture":"arm64"'  /tmp/manifest.json
```

**Pull-by-tag resolution** — inspect immediately after each pull (RESEARCH Pitfall 4: a second pull overwrites the local tag):
```yaml
      - name: Pull-by-tag resolution (amd64 + arm64)
        run: |
          docker pull ghcr.io/geniusventures/almalinux-8:latest
          test "$(docker inspect --format '{{.Architecture}}' ghcr.io/geniusventures/almalinux-8:latest)" = amd64
          docker pull --platform linux/arm64 ghcr.io/geniusventures/almalinux-8:latest
          test "$(docker inspect --format '{{.Architecture}}' ghcr.io/geniusventures/almalinux-8:latest)" = arm64
```

**arm64 run smoke (D-05/D-06) — probe strings reused verbatim from the Dockerfile**:
The probe set is the exact union of the Dockerfile's step-9 chain (lines 92-98) and step-10 chain (lines 219-223):
```yaml
      - name: arm64 run smoke test (full probe set)
        run: |
          docker run --rm --platform linux/arm64 ghcr.io/geniusventures/almalinux-8:latest bash -ec '
            set -eux
            test "$(uname -m)" = aarch64
            rustc --version | grep -q 1.87.0
            node --version | grep -qE "^v24\."
            node -e "process.exit(0)"
            java -version 2>&1 | grep -q Temurin-25
            ld --version | grep -q "mold 2.42.0"
            clang --version | head -1
            cmake --version | head -1
            gh --version
            pkg-config --version
            pkg-config --exists vulkan
            pkg-config --exists gtk+-3.0
            pkg-config --exists libsecret-1
            rpm -q gnome-keyring vulkan-headers
          '
```

The `rustc 1.87.0` / `node ^v24\.` / `java Temurin-25` / `ld mold 2.42.0` gates come directly from the Dockerfile step-10 block (`almalinux-8/Dockerfile` lines 219-223); the `pkg-config --exists vulkan/gtk+-3.0/libsecret-1` and `gnome-keyring` probes come from step 9 (lines 92-98) and specifically resolve the STACK.md MEDIUM-confidence aarch64 items (D-06).

---

## Shared Patterns

### GitHub Actions workflow shape (apply to the whole file)

**Source:** `.github/workflows/ci.yml`
**Apply to:** `.github/workflows/ci-almalinux.yml`

The repo's single established workflow convention:
- `name:` at top, then `permissions:` (contents: read, packages: write), then `on: [push, workflow_dispatch]`.
- `jobs.<job>.runs-on: ubuntu-latest` with `steps:`.
- Actions pinned to major tags only (`@v4`, `@v6`, `@v7`) — never commit SHAs.
- ghcr.io auth is always `username: ${{github.actor}}` + `password: ${{secrets.GITHUB_TOKEN}}` via `docker/login-action@v4`.

### Version-probe fail-fast gates (apply to smoke step)

**Source:** `almalinux-8/Dockerfile` step 10 (lines 216-228) and `almalinux-8/verify-parity.sh`
**Apply to:** the arm64 smoke `run:` step

The repo verifies toolchains with `--version` / `pkg-config --exists` / `rpm -q` string-grep gates, each `grep -q` failing the shell under `set -e`:
```dockerfile
ld --version | grep -q 'mold 2.42.0'
node --version | grep -q '^v24\.'
rustc --version | grep -q '1.87.0'
java -version 2>&1 | grep -q 'Temurin-25'
```

`verify-parity.sh` (lines 35-49) demonstrates the same convention in a `bash -c` run context: `printf "tool=%s\n" "$(tool --version | awk ...)"` then `grep "^field="` for comparison. The smoke reuses these strings verbatim so the post-push smoke is a runtime re-check of the exact build-time gates.

### Arch-clean case-label map (apply to the arch-clean gate)

**Source:** `almalinux-8/Dockerfile` lines 113-115, 150-152, 173-175
**Apply to:** the arch-clean gate `grep` expression

The established pattern for arch dispatch is a `case "$(uname -m)"` with exactly two arms (`x86_64`/`aarch64`) plus a hard `*) ... exit 1 ;;` default. The gate's regex `(armhf|i386)\)` targets the `case` label form so it matches the (deleted) branch labels without matching the documentation comments that say "the armhf/i386 branches are deleted" (lines 143, 165).

---

## No Analog Found

No files lack an analog. The new workflow is a direct one-to-one mirror of `.github/workflows/ci.yml` plus the Dockerfile's in-image verification chains; no novel pattern is required.

## Metadata

**Analog search scope:** `.github/workflows/`, `almalinux-8/` (Dockerfile, verify-parity.sh)
**Files scanned:** `.github/workflows/ci.yml`, `almalinux-8/Dockerfile`, `almalinux-8/verify-parity.sh`
**Pattern extraction date:** 2026-09-09
