# syntax=docker/dockerfile:1
FROM almalinux:8

ENV RUSTUP_HOME=/usr/local/rustup \
    CARGO_HOME=/usr/local/cargo \
    PATH=/usr/local/cargo/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH \
    RUST_VERSION=1.87.0

# 1) Bootstrap dnf tooling + base utilities.
#    dnf config-manager lives in dnf-plugins-core and is NOT guaranteed present in the
#    minimal image — it must be installed before any `dnf config-manager` call below.
RUN <<EOF

set -eux

dnf install -y dnf-plugins-core wget curl tar gzip xz ca-certificates chkconfig && dnf clean all

EOF

# 2) EPEL (pulled from the Extras repo, which almalinux:8 ships enabled). Kept per
#    BASE-02 order; a documented fallback source even though this phase's packages are native.
RUN <<EOF

set -eux

dnf install -y epel-release && dnf clean all

EOF

# 3) PowerTools / CodeReady Builder. AlmaLinux 8 repo id = 'powertools' (the 9-series
#    repo id is different — do not use it). Source of libcurl-devel and ninja-build.
RUN dnf config-manager --set-enabled powertools

# 4) GitHub CLI official rpm repo (gh is in no EL repo).
RUN dnf config-manager --add-repo https://cli.github.com/packages/rpm/gh-cli.repo

# 5) NodeSource 24.x rpm repo (enabled here per BASE-02; the Node runtime itself is
#    installed in Phase 2). Fetched over TLS with -fsSL (fail on error) and deleted after use.
RUN <<EOF

set -eux

curl -fsSL https://rpm.nodesource.com/setup_24.x -o /tmp/nodesource_setup.sh && bash /tmp/nodesource_setup.sh && rm /tmp/nodesource_setup.sh && dnf clean all

EOF

# 6) Enable AppStream modules before install. clang is delivered ONLY via the llvm-toolset
#    module, so this must precede any `dnf install clang`.
RUN dnf module enable llvm-toolset -y

# 7) Pin the Ruby module stream before install — ruby/ruby-devel resolves to 3.1.x
#    (NOT the EOL default 2.5) per 01-RESEARCH.md Q1 (RESOLVED).
RUN dnf module enable ruby:3.1 -y

# 8) Single install transaction — full mapped PKG-01 package set.
#    The Node runtime is deliberately EXCLUDED (Phase 2). chkconfig is already in the bootstrap layer.
RUN <<EOF

set -eux

dnf install -y \
    sudo \
    pkgconf-pkg-config \
    git \
    ruby ruby-devel \
    clang \
    cmake \
    make gcc gcc-c++ binutils \
    gh \
    openssl-devel \
    libcurl-devel \
    libsecret-devel \
    dbus dbus-daemon dbus-tools \
    gnome-keyring \
    ninja-build \
    vulkan-loader vulkan-loader-devel vulkan-headers \
    gtk3-devel \
    jq \
    libatomic \
&& dnf clean all \
&& rm -rf /var/cache/dnf

EOF

# 9) In-image verification chain — fails the build if any package is missing or
#    unresolved. The final three probes are non-fatal diagnostics for the unresolved
#    repo placements from the research checklist (report only, do not hard-fail).
RUN <<EOF

set -eux

pkg-config --version && gcc --version | head -1 && clang --version | head -1 \
  && cmake --version | head -1 && ninja --version && git --version \
  && gh --version && ruby --version && wget --version | head -1 \
  && curl --version | head -1 && jq --version && ld --version | head -1 \
  && pkg-config --exists vulkan && pkg-config --exists gtk+-3.0 \
  && pkg-config --exists libsecret-1 && rpm -q libatomic

dnf info libsecret-devel | grep -E '^Repo' || true
dnf info libcurl-devel | grep -E '^Repo' || true
dnf info vulkan-loader-devel | grep -E '^Repo' || true

EOF
