==> building cidocker-almalinux-8:parity from almalinux-8/Dockerfile
#0 building with "default" instance using docker driver

#1 [internal] load build definition from Dockerfile
#1 transferring dockerfile: 8.34kB done
#1 DONE 0.0s

#2 resolve image config for docker-image://docker.io/docker/dockerfile:1
#2 DONE 0.4s

#3 docker-image://docker.io/docker/dockerfile:1@sha256:ecfaec9ed6d810b56388c508f4121597bfbba70d41a6dfeee4d8cad5f295fc32
#3 resolve docker.io/docker/dockerfile:1@sha256:ecfaec9ed6d810b56388c508f4121597bfbba70d41a6dfeee4d8cad5f295fc32 0.1s done
#3 CACHED

#4 [internal] load metadata for docker.io/library/almalinux:8
#4 DONE 0.2s

#5 [internal] load .dockerignore
#5 transferring context: 2B done
#5 DONE 0.0s

#6 [ 1/17] FROM docker.io/library/almalinux:8@sha256:9f355ae942d6a6c0561f0771dc053a2cfae9580fc45fa4252756db7c7e80c09f
#6 resolve docker.io/library/almalinux:8@sha256:9f355ae942d6a6c0561f0771dc053a2cfae9580fc45fa4252756db7c7e80c09f 0.0s done
#6 DONE 0.1s

#7 [ 8/17] RUN dnf module enable ruby:3.1 -y
#7 CACHED

#8 [15/17] RUN git config --system --add safe.directory '*'
#8 CACHED

#9 [ 2/17] RUN <<EOF (set -eux...)
#9 CACHED

#10 [ 5/17] RUN dnf config-manager --add-repo https://cli.github.com/packages/rpm/gh-cli.repo
#10 CACHED

#11 [ 6/17] RUN <<EOF (set -eux...)
#11 CACHED

#12 [13/17] RUN <<EOF (set -eux...)
#12 CACHED

#13 [ 9/17] RUN <<EOF (set -eux...)
#13 CACHED

#14 [ 7/17] RUN dnf module enable llvm-toolset -y
#14 CACHED

#15 [11/17] RUN <<EOF (set -eux...)
#15 CACHED

#16 [14/17] RUN <<EOF (set -eux...)
#16 CACHED

#17 [12/17] RUN <<EOF (set -eux...)
#17 CACHED

#18 [16/17] RUN mkdir -p /var/lib/dbus &&     cat /proc/sys/kernel/random/uuid | tr -d '-' > /etc/machine-id
#18 CACHED

#19 [ 4/17] RUN dnf config-manager --set-enabled powertools
#19 CACHED

#20 [10/17] RUN <<EOF (set -eux...)
#20 CACHED

#21 [ 3/17] RUN <<EOF (set -eux...)
#21 CACHED

#22 [17/17] RUN <<EOF (set -eux...)
#22 CACHED

#23 exporting to image
#23 exporting layers done
#23 exporting manifest sha256:625601c140915e5b646919a2621c6393797f3b2d6e4c11ece971fa429ed2ff74 done
#23 exporting config sha256:5a598e1b701efe4c9fbba0929828d73076ae2094819b95bc2db717e0d19b0b2e done
#23 exporting attestation manifest sha256:9e5aabe8e98b05bc4f5b11fc3a18963d22bbec036c641d0df4b4c0fa2ae006dd 0.1s done
#23 exporting manifest list sha256:d1b239587737e2f2fe881843129cefb7c359f9f2bb5ea63040dc1fedfd3affb2
#23 exporting manifest list sha256:d1b239587737e2f2fe881843129cefb7c359f9f2bb5ea63040dc1fedfd3affb2 0.0s done
#23 naming to docker.io/library/cidocker-almalinux-8:parity 0.0s done
#23 unpacking to docker.io/library/cidocker-almalinux-8:parity 0.0s done
#23 DONE 0.2s
==> pulling frozen ghcr.io/geniusventures/debian-bullseye:latest (pushed by ci.yml)
latest: Pulling from geniusventures/debian-bullseye
Digest: sha256:62bd7fe3767567d642f47491b8a3cf7e20deea717058654b8ff1f9e52d92a368
Status: Image is up to date for ghcr.io/geniusventures/debian-bullseye:latest
ghcr.io/geniusventures/debian-bullseye:latest
==> version matrix (bullseye)
rustc=1.87.0
node=24
java=25
mold=2.42.0
clang=Debian clang version 11.0.1-2
cmake=cmake version 3.25.1
ruby=2.7.4p191
gtk=3.24.24
glibc=2.31
==> version matrix (almalinux)
rustc=1.87.0
node=24
java=25
mold=2.42.0
clang=clang version 21.1.8 ( 21.1.8-1.module_el8.10.0+4172+b6b13d75)
cmake=cmake version 3.26.5
ruby=3.1.7p261
gtk=3.22.30
glibc=2.28
PASS: stated-major matrix (rustc/node/java/mold) matches
==> fixture (bullseye)
cpp-ok 15
rust-ok 15
node-ok
java-ok
gtk-ok
==> fixture (almalinux)
cpp-ok 15
rust-ok 15
node-ok
java-ok
gtk-ok
PASS: behavioral fixture output identical
==> ruby drift probe (D-09)
ruby=2.7.4p191
ruby=3.1.7p261
ruby-ok 2.7.4
ruby-ok 3.1.7
NOTE: ruby 2.7 (bullseye) -> 3.1 (EL8) is documented, accepted drift (D-09).
==> clang drift (D-08) — documented accept-risk, no active diffing
clang=Debian clang version 11.0.1-2
clang=clang version 21.1.8 ( 21.1.8-1.module_el8.10.0+4172+b6b13d75)
NOTE: clang major-version drift (bullseye 11.x -> EL8 llvm-toolset) is documented, accepted drift (D-08).
==> GTK gap (PAR-02) — version + compile probe
gtk=3.24.24
gtk=3.22.30
==> GTK host monorepo grep (D-07, report-only)
MONOREPO=/w/gnus/GeniusNetwork  (override with: export MONOREPO=/mnt/w/gnus/GeniusNetwork under WSL)
NOTE: monorepo not found at /w/gnus/GeniusNetwork — skipping host grep (set MONOREPO to run it).
ALL PARITY CHECKS PASSED
