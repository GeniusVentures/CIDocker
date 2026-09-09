---
status: testing
phase: 04-multi-arch-verification
source: [04-VERIFICATION.md]
started: 2026-09-09
updated: 2026-09-09
---

## Current Test

number: 1
name: Post-push ci-almalinux Actions run
expected: |
  The workflow run is green end-to-end; the OCI index at `ghcr.io/geniusventures/almalinux-8:latest`
  carries both `amd64` and `arm64` manifests; the arm64 container runs under QEMU and every tool probe passes.
awaiting: user response

## Tests

### 1. Post-push ci-almalinux Actions run
expected: After pushing to GitHub, open the `ci-almalinux` workflow run in Actions and confirm: (1) `Build and push (multi-arch)` succeeds; (2) `Verify multi-arch manifest (PAR-03)` shows both `amd64` and `arm64` digests; (3) `Pull-by-tag resolution (amd64 + arm64)` shows `amd64` then `arm64`; (4) `arm64 run smoke test (full probe set)` passes all 14 probes with `uname -m` = `aarch64`.
result: [pending]

## Summary

total: 1
passed: 0
issues: 0
pending: 1
skipped: 0
blocked: 0

## Gaps
