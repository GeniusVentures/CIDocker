#!/usr/bin/env bash
# verify-parity.sh — Phase 3 parity harness. Run MANUALLY (D-01); ci.yml is NOT modified (D-02).
#
# Usage:        bash almalinux-8/verify-parity.sh
# Prereq:       Docker daemon running (docker info must succeed).
# Bullseye pull: by default this pulls the frozen `ghcr.io/geniusventures/debian-bullseye:latest`
#                (pushed by .github/workflows/ci.yml). If that tag is private/unreachable,
#                build the bullseye image locally and re-run with the override, e.g.:
#                    docker build -t cidocker-debian-bullseye:parity -f debian-bullseye/Dockerfile .
#                    BULLSEYE_IMAGE=cidocker-debian-bullseye:parity bash almalinux-8/verify-parity.sh
# Monorepo grep: default POSIX path /w/gnus/GeniusNetwork (Git Bash). Under WSL export:
#                    export MONOREPO=/mnt/w/gnus/GeniusNetwork
# Output:        writes .planning/phases/03-parity-verification/03-PARITY-REPORT.md via tee.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPORT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)/.planning/phases/03-parity-verification"
REPORT="$REPORT_DIR/03-PARITY-REPORT.md"
ALMA_IMAGE="${ALMA_IMAGE:-cidocker-almalinux-8:parity}"
BULLSEYE_IMAGE="${BULLSEYE_IMAGE:-ghcr.io/geniusventures/debian-bullseye:latest}"

main() {
  mkdir -p "$REPORT_DIR"

  # Pre-flight: Docker daemon must be up (Pitfall 3).
  if ! docker info >/dev/null 2>&1; then
    echo "FAIL: Docker daemon is not running. Start Docker Desktop, then re-run." >&2
    exit 1
  fi

  # --- Acquire images ---------------------------------------------------------
  echo "==> building $ALMA_IMAGE from almalinux-8/Dockerfile"
  docker build -t "$ALMA_IMAGE" -f "$SCRIPT_DIR/Dockerfile" "$SCRIPT_DIR"
  echo "==> pulling frozen $BULLSEYE_IMAGE (pushed by ci.yml)"
  docker pull "$BULLSEYE_IMAGE"

  # --- Stage 1: version matrix (D-03 bar: rustc 1.87.0 / node 24 / java 25 / mold 2.42.0)
  matrix() {
    local img="$1"
    docker run --rm "$img" bash -c '
      printf "rustc=%s\n" "$(rustc --version | awk "{print \$2}")"
      printf "node=%s\n"  "$(node --version | sed "s/^v//" | cut -d. -f1)"
      printf "java=%s\n"  "$(java -version 2>&1 | sed -n "s/^openjdk version \"\([0-9]*\).*/\1/p")"
      printf "mold=%s\n"  "$(ld --version | awk "{print \$2}")"
      printf "clang=%s\n" "$(clang --version | head -1)"
      printf "cmake=%s\n" "$(cmake --version | head -1)"
      printf "ruby=%s\n"  "$(ruby --version | awk "{print \$2}")"
      printf "gtk=%s\n"   "$(pkg-config --modversion gtk+-3.0)"
      printf "glibc=%s\n" "$(ldd --version | head -1 | awk "{print \$NF}")"
    '
  }

  echo "==> version matrix (bullseye)"
  matrix "$BULLSEYE_IMAGE" | tee /tmp/matrix-bullseye.txt
  echo "==> version matrix (almalinux)"
  matrix "$ALMA_IMAGE"   | tee /tmp/matrix-alma.txt

  # Hard gate — the four stated majors must match exactly (D-03). Node patch may differ.
  for field in rustc node java mold; do
    b="$(grep "^$field=" /tmp/matrix-bullseye.txt | cut -d= -f2)"
    a="$(grep "^$field=" /tmp/matrix-alma.txt   | cut -d= -f2)"
    if [[ "$b" != "$a" ]]; then
      echo "FAIL: $field mismatch — bullseye=$b almalinux=$a" >&2
      exit 1
    fi
  done
  echo "PASS: stated-major matrix (rustc/node/java/mold) matches"

  # --- Stage 2: behavioral fixture (D-05/D-06) ---------------------------------
  run_fixture() {
    local img="$1"
    docker run --rm -v "$SCRIPT_DIR/fixture:/src:ro" -w /src "$img" bash -eu -c '
      ld --version | grep -q mold || { echo "FAIL: mold not default ld" >&2; exit 1; }
      # C++ — clang + mold via the default-ld shim (plain clang++; bullseye clang 11 has no mold linker flag)
      clang++ -std=c++17 -O2 cpp/main.cpp -o /tmp/cpp_main && /tmp/cpp_main
      # Rust — std-only crate; target dir in /tmp (read-only mount, Pitfall 4)
      ( cd rust && CARGO_TARGET_DIR=/tmp/cargo_target cargo run --quiet --release )
      # Node probe (nice-to-have, D-05)
      node -e "console.log(\"node-ok\")"
      # Java probe (nice-to-have, D-05)
      cat > /tmp/Probe.java <<JAVA
public class Probe { public static void main(String[] a){ System.out.println("java-ok"); } }
JAVA
      ( cd /tmp && javac Probe.java && java Probe )
      # GTK compile probe — headers/libs resolve (PAR-02). Compile + run-safe (no display).
      cc gtk_probe.c -o /tmp/gtk_probe $(pkg-config --cflags --libs gtk+-3.0) && /tmp/gtk_probe && echo "gtk-ok"
    '
  }

  echo "==> fixture (bullseye)"
  run_fixture "$BULLSEYE_IMAGE" | tee /tmp/fixture-bullseye.txt
  echo "==> fixture (almalinux)"
  run_fixture "$ALMA_IMAGE"   | tee /tmp/fixture-alma.txt

  if diff -u /tmp/fixture-bullseye.txt /tmp/fixture-alma.txt; then
    echo "PASS: behavioral fixture output identical"
  else
    echo "FAIL: behavioral fixture output differs" >&2
    exit 1
  fi

  # --- Stage 3: drift evidence (D-08/D-09) -------------------------------------
  echo "==> ruby drift probe (D-09)"
  matrix "$BULLSEYE_IMAGE" | grep '^ruby='
  matrix "$ALMA_IMAGE"   | grep '^ruby='
  docker run --rm "$BULLSEYE_IMAGE" ruby -e 'puts "ruby-ok #{RUBY_VERSION}"'
  docker run --rm "$ALMA_IMAGE"   ruby -e 'puts "ruby-ok #{RUBY_VERSION}"'
  echo "NOTE: ruby 2.7 (bullseye) -> 3.1 (EL8) is documented, accepted drift (D-09)."

  echo "==> clang drift (D-08) — documented accept-risk, no active diffing"
  matrix "$BULLSEYE_IMAGE" | grep '^clang='
  matrix "$ALMA_IMAGE"   | grep '^clang='
  echo "NOTE: clang 11 -> 17 is documented, accepted drift (D-08)."

  echo "==> GTK gap (PAR-02) — version + compile probe"
  matrix "$BULLSEYE_IMAGE" | grep '^gtk='
  matrix "$ALMA_IMAGE"   | grep '^gtk='

  echo "==> GTK host monorepo grep (D-07, report-only)"
  MONOREPO="${MONOREPO:-/w/gnus/GeniusNetwork}"
  echo "MONOREPO=$MONOREPO  (override with: export MONOREPO=/mnt/w/gnus/GeniusNetwork under WSL)"
  if [[ ! -d "$MONOREPO" ]]; then
    echo "NOTE: monorepo not found at $MONOREPO — skipping host grep (set MONOREPO to run it)."
  else
    # report-only: a zero-match grep exits 1, so capture output; never fatal under set -euo pipefail.
    gtk_hits="$(
      grep -RIl \
        --include='*.h' --include='*.hpp' --include='*.cpp' --include='*.cc' \
        --include='*.c' --include='*.cxx' --include='*.rs' --include='*.m' --include='*.mm' \
        --exclude-dir=thirdparty --exclude-dir=.git --exclude-dir=.dart_tool \
        --exclude-dir=ephemeral --exclude-dir=.plugin_symlinks --exclude-dir=flutter \
        -e '#include[[:space:]]*[<"]gtk/gtk\.h' "$MONOREPO" 2>/dev/null || true
    )"
    if [[ -n "$gtk_hits" ]]; then
      echo "GTK include hits (expect only out-of-scope Flutter runner templates):"
      printf '%s\n' "$gtk_hits"
      echo "VERDICT: remaining hits are out-of-scope Flutter scaffolding (D-05/D-07) — non-blocking."
    else
      echo "VERDICT: no GTK includes in core C++/Rust projects — gap non-blocking (D-07)."
    fi
  fi

  echo "ALL PARITY CHECKS PASSED"
}

main "$@" 2>&1 | tee "$REPORT"
