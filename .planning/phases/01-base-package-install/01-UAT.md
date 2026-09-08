---
status: testing
phase: 01-base-package-install
source: [01-01-SUMMARY.md, 01-02-SUMMARY.md]
started: 2026-09-08T23:08:50Z
updated: 2026-09-08T23:08:50Z
---

## Current Test

number: 1
name: Image builds and reports glibc 2.28
expected: |
  docker build -t cidocker-almalinux-8:phase1 -f almalinux-8/Dockerfile . exits 0;
  docker run --rm cidocker-almalinux-8:phase1 ldd --version | head -1 contains 2.28
awaiting: user response

## Tests

### 1. Image builds and reports glibc 2.28
expected: `docker build -t cidocker-almalinux-8:phase1 -f almalinux-8/Dockerfile .` exits 0, then `docker run --rm cidocker-almalinux-8:phase1 ldd --version | head -1` contains `2.28`.
result: pending

### 2. All repos are enabled in order
expected: `docker run --rm cidocker-almalinux-8:phase1 dnf repolist` lists baseos, appstream, extras, epel, powertools, gh-cli, and a nodesource repo.
result: pending

### 3. Every PKG-01 package verifies in-image
expected: `docker run --rm cidocker-almalinux-8:phase1 pkg-config --exists vulkan`, `pkg-config --exists gtk+-3.0`, and `pkg-config --exists libsecret-1` exit 0; `docker run --rm cidocker-almalinux-8:phase1 ruby --version` reports 3.1.x.
result: pending

### 4. Lean image (no dnf package cache)
expected: `docker images cidocker-almalinux-8:phase1 --format "{{.Size}}"` reports a reasonable size (dnf cache cleaned), comparable to `debian-bullseye`.
result: pending

## Summary

total: 4
passed: 0
issues: 0
pending: 4
skipped: 0
blocked: 0

## Gaps

<!-- No gaps yet — appended only when a test reports an issue. -->
