---
status: complete
phase: 04-multi-arch-verification
source: [04-VERIFICATION.md]
started: 2026-09-09
updated: 2026-09-09
---

## Current Test

[testing complete]

## Tests

### 1. Post-push ci-almalinux Actions run
expected: After pushing to GitHub, open the `ci-almalinux` workflow run in Actions and confirm: (1) `Build and push (multi-arch)` succeeds; (2) `Verify multi-arch manifest (PAR-03)` shows both `amd64` and `arm64` digests; (3) `Pull-by-tag resolution (amd64 + arm64)` shows `amd64` then `arm64`; (4) `arm64 run smoke test (full probe set)` passes all 14 probes with `uname -m` = `aarch64`.
result: pass
verified_by: "Green run 34382974387 (commit 252d455) observed 2026-09-09 — all steps ✓ including manifest dual-digest, pull-by-tag amd64→arm64, and full 14-probe arm64 smoke under QEMU (gnome-keyring-3.28.2-2.el8_10.aarch64, vulkan-headers-1.3.283.0-1.el8_10.noarch both resolved). Initial failure in run 34329153883 was the minified-JSON grep; fixed in 831e866 (whitespace-tolerant grep -Eq) and re-verified green."

## Summary

total: 1
passed: 1
issues: 0
pending: 0
skipped: 0
blocked: 0

## Gaps

[none — the single gap recorded below was resolved by commit 831e866 and proven green by run 34382974387; kept for audit trail]

- truth: "Verify multi-arch manifest (PAR-03) step greps both amd64 and arm64 digests out of the raw OCI index and passes"
  status: resolved
  reason: "User reported: CI run 34329153883 failed at 'Verify multi-arch manifest (PAR-03)' with exit code 1: docker buildx imagetools inspect --raw returns pretty-printed JSON from ghcr, but the grep matched only the minified form \"architecture\":\"amd64\". The push itself succeeded — the index at ghcr.io/geniusventures/almalinux-8:latest verifiably contains both amd64 (sha256:f22b1589...) and arm64 (sha256:e1c0cf0e...) manifests — but the verification step's grep never matched, so the downstream pull-by-tag and arm64 smoke steps were skipped."
  severity: major
  test: 1
  root_cause: "grep pattern in ci-almalinux.yml assumed minified JSON ('\"architecture\":\"amd64\"'), but docker buildx imagetools inspect --raw against ghcr.io returns pretty-printed JSON with spaces after colons ('\"architecture\": \"amd64\"')"
  resolution: "Commit 831e866 switched both greps to whitespace-tolerant 'grep -Eq \"\\\"architecture\\\":[[:space:]]*\\\"amd64\\\"\"' form; validated against the live manifest; green run 34382974387 proves all downstream steps pass"
  artifacts:
    - ".github/workflows/ci-almalinux.yml"
  missing: []
  debug_session: ""
