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

# `which` restores debianutils parity: CI scripts across the GNUS repos invoke
# `$(which clang)` for update-alternatives; the minimal EL8 image omits it.
# perl + perl-IPC-Cmd are required by OpenSSL's Configure script (Debian ships
# IPC::Cmd in core perl; EL8 splits it into a subpackage).
dnf install -y dnf-plugins-core wget curl tar gzip xz ca-certificates chkconfig which perl perl-IPC-Cmd && dnf clean all

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
#    git-lfs comes from EPEL (enabled in step 2): downstream repo CI checkouts
#    use actions/checkout with lfs:true (e.g. SuperGenius's .cap test fixtures).
#    genius-ai-boss additions (verified in its cmake.yml + green run 42927876765):
#      * ccache — Linux lanes cache native builds through
#        CMAKE_[C|CXX]_COMPILER_LAUNCHER (EPEL, 3.7.7-1.el8).
#      * python3.11 + pip — the scaffold's jinja2 floor is >=3.1 (needs
#        python >=3.7); EL8's default python3 is 3.6.
#      * java-17-openjdk-devel — the Android Gradle lane's JVM. Temurin 25
#        stays the default `java` (PATH precedence); flutter's pinned Gradle
#        cannot run on 25, so the workflow probes /usr/lib/jvm/java-17-openjdk*
#        and overrides JAVA_HOME for Android steps (it needs javac, hence
#        -devel not -headless).
#      * unzip — android-actions/setup-android shells out to system unzip.
RUN <<EOF

set -eux

dnf install -y \
    sudo \
    pkgconf-pkg-config \
    git \
    git-lfs \
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
    ccache \
    unzip \
    python3.11 python3.11-pip \
    java-17-openjdk-devel \
&& dnf clean all \
&& rm -rf /var/cache/dnf

EOF

# 9) In-image verification chain — fails the build if any package is missing or
#    unresolved. The final three probes are non-fatal diagnostics for the unresolved
#    repo placements from the research checklist (report only, do not hard-fail).
RUN <<EOF

set -eux

pkg-config --version && gcc --version | head -1 && clang --version | head -1 \
  && cmake --version | head -1 && ninja --version && git --version && git-lfs version \
  && gh --version && ruby --version && wget --version | head -1 \
  && curl --version | head -1 && jq --version && ld --version | head -1 \
  && pkg-config --exists vulkan && pkg-config --exists gtk+-3.0 \
  && pkg-config --exists libsecret-1 && rpm -q libatomic
ccache --version | head -1 && python3.11 --version && unzip -v | head -1 \
  && ls -d /usr/lib/jvm/java-17-openjdk-*/ >/dev/null

# `which` and perl IPC::Cmd are load-bearing for downstream CI: GNUS repo
# workflows call `$(which clang)` for update-alternatives, and OpenSSL's
# Configure (built from source in thirdparty) requires IPC::Cmd.
command -v which && which clang && which perl
perl -MIPC::Cmd -e 'print "IPC::Cmd OK\n"'

dnf info libsecret-devel | grep -E '^Repo' || true
dnf info libcurl-devel | grep -E '^Repo' || true
dnf info vulkan-loader-devel | grep -E '^Repo' || true

EOF

# sudo for arbitrary runner UIDs. Container jobs may execute as the host runner
# service user (1001 on one machine, 1002 on another); the runner appends that
# user's line to /etc/passwd but creates no /etc/shadow entry, and EL8 pam_unix
# account validation then fails with "Authentication service cannot retrieve
# authentication info" (Debian's Linux-PAM 1.4 tolerates the shadow-less entry;
# bullseye-era jobs also ran as container root, where sudo needs no PAM). The
# UID differs per machine, so the fix must be UID-agnostic: passwordless sudo
# for any user, plus !pam_acct_mgmt to skip the account phase that trips on the
# missing shadow entry. Equivalent access to the root the job already has via
# the workspace mounts.
RUN <<EOF
set -eux
printf 'Defaults !pam_acct_mgmt\nALL ALL=(ALL) NOPASSWD: ALL\n' > /etc/sudoers.d/99-ci-arbitrary-uid
chmod 440 /etc/sudoers.d/99-ci-arbitrary-uid
visudo -cf /etc/sudoers.d/99-ci-arbitrary-uid >/dev/null
EOF

# mold: EL8 has no mold package and GCC 8.5 cannot pass -fuse-ld=mold, so install
# the upstream static build and register it as the default ld. Revert with
# `update-alternatives --set ld /usr/bin/ld.bfd` if a link ever misbehaves.
RUN <<EOF

set -eux

case "$(uname -m)" in \
    x86_64) moldArch='x86_64' ;; \
    aarch64) moldArch='aarch64' ;; \
    *) echo >&2 "unsupported architecture for mold: $(uname -m)"; exit 1 ;; \
esac; \

moldVersion="2.42.0"; \
moldArchive="mold-${moldVersion}-${moldArch}-linux.tar.gz"; \
cd /tmp; \
wget -q "https://github.com/rui314/mold/releases/download/v${moldVersion}/${moldArchive}"; \
tar -xzf "${moldArchive}" -C /usr/local --strip-components=1; \
rm "${moldArchive}"; \
update-alternatives --install /usr/bin/ld ld /usr/local/bin/ld.mold 100; \
ld --version;

EOF

# Node 24 (rolling, parity with bullseye). The NodeSource rpm repo was enabled in
# Phase 1 step 5; nothing to configure here beyond the install. Node 24 sits exactly
# on the glibc 2.28 floor — the clean-exit probe asserts the binary links and runs.
RUN <<EOF

set -eux

dnf install -y nodejs && dnf clean all
node --version
node -e 'process.exit(0)'

EOF

# Backend codegen toolchain (genius-ai-boss cmake.yml parity): the scaffold
# FATALs at configure without openapi-generator-cli and the ExternalProject
# domain/plugin generation runs it at build time. The workflow currently npm
# -installs this EVERY run — baking it removes that cold path. Pinned to the
# exact version green run 42927876765 installed. The generator JARs themselves
# stay per-repo pins (openapitools.json) and are warmed at job time as before.
RUN <<EOF

set -eux

npm install -g @openapitools/openapi-generator-cli@2.42.1
command -v openapi-generator-cli

EOF

# Codegen python: the workflow's "Prepare codegen venv (jinja2)" step builds a
# run-unique venv from python3.11 (installed in step 8) and pip-installs
# jinja2>=3.1 from PyPI each run. Baking jinja2 into the system python3.11
# makes the interpreter import-ready for any consumer; the run-unique venv
# stays the workflow's own (root-owned-residue isolation is deliberate there).
# Pinned to jinja2 3.1.6 (what run 42927876765 resolved).
RUN <<EOF

set -eux

python3.11 -m pip install --no-cache-dir "jinja2==3.1.6"
python3.11 -c 'import jinja2; print("jinja2", jinja2.__version__)'

EOF

# Rust via SHA256-pinned rustup (parity with bullseye). amd64 + arm64 only (BASE-03);
# the armhf/i386 branches are deleted. RUST_VERSION/RUSTUP_HOME/CARGO_HOME come from
# the top ENV block.
RUN <<EOF

set -eux

case "$(uname -m)" in \
    x86_64) rustArch='x86_64-unknown-linux-gnu'; rustupSha256='20a06e644b0d9bd2fbdbfd52d42540bdde820ea7df86e92e533c073da0cdd43c' ;; \
    aarch64) rustArch='aarch64-unknown-linux-gnu'; rustupSha256='e3853c5a252fca15252d07cb23a1bdd9377a8c6f3efa01531109281ae47f841c' ;; \
    *) echo >&2 "unsupported architecture: $(uname -m)"; exit 1 ;; \
esac; \

url="https://static.rust-lang.org/rustup/archive/1.28.2/${rustArch}/rustup-init"; \
wget "$url"; \
echo "${rustupSha256} *rustup-init" | sha256sum -c -; \
chmod +x rustup-init; \
./rustup-init -y --no-modify-path --profile minimal --default-toolchain $RUST_VERSION --default-host ${rustArch}; \
rm rustup-init; \
chmod -R a+w $RUSTUP_HOME $CARGO_HOME;

EOF

# Temurin JDK 25 via Adoptium tarball (parity). x64/aarch64 only; the armhf/i386
# error branches are deleted. The extracted top-level dir is discovered dynamically
# (it is jdk-25.0.2+10) — do not hardcode it.
RUN <<EOF

set -eux

case "$(uname -m)" in \
    x86_64) jdkArch='x64'; javaDir='amd64' ;; \
    aarch64) jdkArch='aarch64'; javaDir='arm64' ;; \
    *) echo >&2 "unsupported architecture: $(uname -m)"; exit 1 ;; \
esac; \

mkdir -p /usr/lib/jvm; \
cd /tmp; \
jdkReleaseTag="jdk-25.0.2+10"; \
jdkArchive="OpenJDK25U-jdk_${jdkArch}_linux_hotspot_25.0.2_10.tar.gz"; \
wget -q "https://github.com/adoptium/temurin25-binaries/releases/download/${jdkReleaseTag}/${jdkArchive}"; \
extractedDir="$(tar -tzf "${jdkArchive}" | head -1 | cut -d/ -f1)"; \
test -n "${extractedDir}"; \
tar -xzf "${jdkArchive}" -C /usr/lib/jvm; \
mv "/usr/lib/jvm/${extractedDir}" "/usr/lib/jvm/temurin-25-jdk-${javaDir}"; \
ln -sfn /usr/lib/jvm/temurin-25-jdk-${javaDir} /usr/lib/jvm/temurin-25-jdk; \
rm "${jdkArchive}"; \

javaHome="/usr/lib/jvm/temurin-25-jdk"; \
echo "export JAVA_HOME=${javaHome}" >> /etc/profile.d/java-env.sh; \
echo "export JAVA_INCLUDE_PATH=\$JAVA_HOME/include" >> /etc/profile.d/java-env.sh; \
echo "export JAVA_INCLUDE_PATH2=\$JAVA_HOME/include/linux" >> /etc/profile.d/java-env.sh; \
echo "export JAVA_AWT_INCLUDE_PATH=\$JAVA_HOME/include" >> /etc/profile.d/java-env.sh;

EOF

ENV JAVA_HOME=/usr/lib/jvm/temurin-25-jdk \
    JAVA_INCLUDE_PATH=/usr/lib/jvm/temurin-25-jdk/include \
    JAVA_INCLUDE_PATH2=/usr/lib/jvm/temurin-25-jdk/include/linux \
    JAVA_AWT_INCLUDE_PATH=/usr/lib/jvm/temurin-25-jdk/include \
    JAVA_JVM_LIBRARY=/usr/lib/jvm/temurin-25-jdk/lib/server/libjvm.so \
    JDK_HOME=/usr/lib/jvm/temurin-25-jdk \
    ANDROID_HOME=/opt/android-sdk \
    ANDROID_SDK_ROOT=/opt/android-sdk \
    PATH=/usr/lib/jvm/temurin-25-jdk/bin:/opt/android-sdk/cmdline-tools/22.0/bin:/opt/android-sdk/platform-tools:/usr/local/cargo/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

RUN git config --system --add safe.directory '*'

# machine-id seed: on EL8 /var/lib/dbus/machine-id is a SYMLINK to /etc/machine-id
# (systemd convention, present in the base image), so seeding /etc/machine-id is
# sufficient — the bullseye `cp` would be a self-copy error (same inode on EL8).
RUN mkdir -p /var/lib/dbus && \
    cat /proc/sys/kernel/random/uuid | tr -d '-' > /etc/machine-id

# Android SDK at a fixed, image-consistent path (/opt/android-sdk): the SAME
# components the genius-ai-boss cmake.yml Android lane builds up on each
# runner — android-actions/setup-android@be39fa83 (v4.0.4) downloads
# cmdline-tools 15859902 (-> cmdline-tools/22.0), accepts all licenses and
# installs platform-tools; the touch-pos-system Gradle build then auto-installs
# the rest into that SDK root. Component pins: Flutter 3.41.9 defaults
# (compileSdk 36 / NDK 28.2.13676358 — read from the thirdparty Flutter's
# FlutterExtension.kt), AGP 8.11 native-build CMake 3.22.1, build-tools to match
# compileSdk 36. x86_64 only: Google ships no aarch64 host tools and only the
# Linux-x86_64 lane builds the APK. The workflow still points ANDROID_SDK_ROOT
# at its runner-persistent root — pointing it here instead makes the ~2GB SDK
# travel with the image (setup-android then detects the preinstalled
# cmdline-tools via source.properties and skips its own download).
RUN <<EOF

set -eux

if [ "$(uname -m)" = x86_64 ]; then
    sdkRoot=/opt/android-sdk
    mkdir -p "${sdkRoot}/cmdline-tools"
    cmdlineToolsBuild=15859902
    curl -fsSL -o /tmp/cmdline-tools.zip \
        "https://dl.google.com/android/repository/commandlinetools-linux-${cmdlineToolsBuild}_latest.zip"
    unzip -q /tmp/cmdline-tools.zip -d "${sdkRoot}/cmdline-tools"
    mv "${sdkRoot}/cmdline-tools/cmdline-tools" "${sdkRoot}/cmdline-tools/22.0"
    rm /tmp/cmdline-tools.zip
    sdkmanager="${sdkRoot}/cmdline-tools/22.0/bin/sdkmanager"
    yes | "${sdkmanager}" --licenses > /dev/null
    "${sdkmanager}" \
        "platform-tools" \
        "platforms;android-36" \
        "build-tools;36.0.0" \
        "ndk;28.2.13676358" \
        "cmake;3.22.1" > /dev/null
    rm -rf "${sdkRoot}/.temp"
    touch "${sdkRoot}/repositories.cfg"
fi

EOF

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
ccache --version | head -1
python3.11 -c 'import jinja2; print("jinja2", jinja2.__version__)'
command -v openapi-generator-cli
ls -d /usr/lib/jvm/java-17-openjdk-*/bin/javac
if [ "$(uname -m)" = x86_64 ]; then
    test -x /opt/android-sdk/cmdline-tools/22.0/bin/sdkmanager
    test -x /opt/android-sdk/platform-tools/adb
    test -d /opt/android-sdk/platforms/android-36
    test -d /opt/android-sdk/build-tools/36.0.0
    test -d /opt/android-sdk/ndk/28.2.13676358
    test -d /opt/android-sdk/cmake/3.22.1
    test -d /opt/android-sdk/licenses
fi
echo "JAVA_HOME=$JAVA_HOME JDK_HOME=$JDK_HOME RUSTUP_HOME=$RUSTUP_HOME CARGO_HOME=$CARGO_HOME ANDROID_SDK_ROOT=$ANDROID_SDK_ROOT"

EOF
