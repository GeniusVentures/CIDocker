# syntax=docker/dockerfile:1
FROM debian:bullseye

ENV RUSTUP_HOME=/usr/local/rustup \
    CARGO_HOME=/usr/local/cargo \
    PATH=/usr/local/cargo/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH \
    RUST_VERSION=1.87.0

RUN echo 'deb http://archive.debian.org/debian bullseye-backports main' > /etc/apt/sources.list.d/backports.list

RUN <<EOF

set -eux

apt update
apt install -y -t bullseye-backports \
    sudo \
    pkg-config \
    git \
    ruby-full \
    clang \
    cmake \
    gh \
    wget \
    curl \
    libcurl4-openssl-dev \
    libsecret-1-dev \
    dbus \
    gnome-keyring \
    ninja-build \
    libvulkan-dev

EOF

RUN <<EOF

set -eux

dpkgArch="$(dpkg --print-architecture)"; \
case "${dpkgArch##*-}" in \
    amd64) rustArch='x86_64-unknown-linux-gnu'; rustupSha256='20a06e644b0d9bd2fbdbfd52d42540bdde820ea7df86e92e533c073da0cdd43c' ;; \
    armhf) rustArch='armv7-unknown-linux-gnueabihf'; rustupSha256='3b8daab6cc3135f2cd4b12919559e6adaee73a2fbefb830fadf0405c20231d61' ;; \
    arm64) rustArch='aarch64-unknown-linux-gnu'; rustupSha256='e3853c5a252fca15252d07cb23a1bdd9377a8c6f3efa01531109281ae47f841c' ;; \
    i386) rustArch='i686-unknown-linux-gnu'; rustupSha256='a5db2c4b29d23e9b318b955dd0337d6b52e93933608469085c924e0d05b1df1f' ;; \
    *) echo >&2 "unsupported architecture: ${dpkgArch}"; exit 1 ;; \
esac; \

url="https://static.rust-lang.org/rustup/archive/1.28.2/${rustArch}/rustup-init"; \
wget "$url"; \
echo "${rustupSha256} *rustup-init" | sha256sum -c -; \
chmod +x rustup-init; \
./rustup-init -y --no-modify-path --profile minimal --default-toolchain $RUST_VERSION --default-host ${rustArch}; \
rm rustup-init; \
chmod -R a+w $RUSTUP_HOME $CARGO_HOME;

EOF

RUN <<EOF

set -eux

dpkgArch="$(dpkg --print-architecture)"; \
case "${dpkgArch##*-}" in \
    amd64) jdkArch='x64'; javaDir='amd64' ;; \
    armhf) echo >&2 "armhf is not supported by Temurin JDK 25 Linux binaries"; exit 1 ;; \
    arm64) jdkArch='aarch64'; javaDir='arm64' ;; \
    i386) echo >&2 "i386 not supported by Temurin"; exit 1 ;; \
    *) echo >&2 "unsupported architecture: ${dpkgArch}"; exit 1 ;; \
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
    PATH=/usr/lib/jvm/temurin-25-jdk/bin:/usr/local/cargo/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

RUN git config --system --add safe.directory '*'

RUN mkdir -p /var/lib/dbus && \
    cat /proc/sys/kernel/random/uuid | tr -d '-' > /var/lib/dbus/machine-id && \
    cp /var/lib/dbus/machine-id /etc/machine-id
