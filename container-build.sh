#!/bin/bash
# Fully build PrusaSlicer in a container
# Utilizes podman/docker depending on which is installed on the host.

# Git repository address where PrusaSlicer is located
PS_GIT_REPO="https://github.com/prusa3d/PrusaSlicer"

# The path where PrusaSlicer is located. If not set by a path on the CLI, the
# utility will clone a copy using Git and build it.
BUILD_PS_IN=""

if [[ -d "$1" ]]; then
	echo "Using $1 to build PrusaSlicer"
	BUILD_PS_IN=$1
fi

if [[ -z "$BUILD_PS_IN" ]]; then
	if ! hash git 2>/dev/null; then
		echo "ERROR: Git does not appear to be installed on your platform and it is needed to clone PrusaSlicer"
		exit 1
	fi

	if [[ ! -d "./PrusaSlicer" ]]; then
		git clone $PS_GIT_REPO
	fi

	BUILD_PS_IN=$(readlink -f ./PrusaSlicer)
fi

if ! hash podman 2>/dev/null && ! hash docker 2>/dev/null; then
	echo "ERROR: This utility requires a container runtime to build PrusaSlicer. Please install either docker or podman to continue"
	exit 1
fi

# Detect whether or not we should use podman/docker, preferring podman if it is available
CONTAINER_BIN="$(command -v docker)"
CONTAINER_ARGS=""

if hash podman 2>/dev/null; then
	CONTAINER_BIN="$(command -v podman)"
	CONTAINER_ARGS="--userns=keep-id"
fi

echo "Init build container .."
${CONTAINER_BIN} build -t prusaslicer-compiler - <<EOF
FROM debian:buster

ENV TZ=UTC
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

RUN apt-get update && apt-get install -y \
  apt-transport-https \
  build-essential \
  cmake \
  ca-certificates \
  git \
  libboost-dev \
  libboost-regex-dev \
  libboost-filesystem-dev \
  libboost-thread-dev \
  libboost-log-dev \
  libboost-locale-dev \
  libboost-iostreams-dev \
  libgtk2.0-dev \
  libgtk-3-dev \
  libwxgtk3.0-gtk3-dev \
  locales \
  ninja-build \
  m4 \
  zlib1g-dev \
  && rm -rf /var/lib/apt/lists/* \
  && apt-get autoremove -y \
  && apt-get autoclean

RUN sed -i \
  -e 's/^# \(cs_CZ\.UTF-8.*\)/\1/' \
  -e 's/^# \(de_DE\.UTF-8.*\)/\1/' \
  -e 's/^# \(en_US\.UTF-8.*\)/\1/' \
  -e 's/^# \(es_ES\.UTF-8.*\)/\1/' \
  -e 's/^# \(fr_FR\.UTF-8.*\)/\1/' \
  -e 's/^# \(it_IT\.UTF-8.*\)/\1/' \
  -e 's/^# \(ko_KR\.UTF-8.*\)/\1/' \
  -e 's/^# \(pl_PL\.UTF-8.*\)/\1/' \
  -e 's/^# \(uk_UA\.UTF-8.*\)/\1/' \
  -e 's/^# \(zh_CN\.UTF-8.*\)/\1/' \
  /etc/locale.gen \
  && locale-gen

RUN groupadd slic3r \
  && useradd -g slic3r --create-home --home-dir /home/slic3r slic3r

USER slic3r
ENV USER slic3r
WORKDIR /home/slic3r/
EOF

# Note, this relinks resources to be relative pathed instead of absolute since the inter-container path probably
# differs from the path outside (if the container is run that way)
time ${CONTAINER_BIN} run ${CONTAINER_ARGS} -v "${BUILD_PS_IN}":/home/slic3r/PrusaSlicer:Z -i --rm prusaslicer-compiler <<EOF
  cd /home/slic3r/PrusaSlicer \
  && cd deps && mkdir -p build && cd build \
  && cmake -G Ninja .. \
  && ninja \
  && cd ../.. && mkdir -p build && cd build \
  && cmake .. -G Ninja -DCMAKE_PREFIX_PATH="/home/slic3r/PrusaSlicer/deps/build/destdir/usr/local" -DSLIC3R_STATIC=1 -DCMAKE_INSTALL_PREFIX=/usr \
  && ninja \
  && rm -f resources \
  && ln -sr ../resources resources \
  && exit 0
EOF

echo "Build finished. prusa-slicer can be found in:"
readlink -f PrusaSlicer/build/src/prusa-slicer

# Bring in AppImage utilities and generate an AppImage
${CONTAINER_BIN} build -t prusaslicer-appimage-generator - <<EOF
FROM debian:buster

ENV TZ=UTC
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

RUN apt-get update && apt-get install -y \
  fuse \
  libfuse-dev \
  wget \
  libglib2.0-0 \
  file \
  gpg \
  && rm -rf /var/lib/apt/lists/* \
  && apt-get autoremove -y \
  && apt-get autoclean

RUN sed -i \
  -e 's/^# \(cs_CZ\.UTF-8.*\)/\1/' \
  -e 's/^# \(de_DE\.UTF-8.*\)/\1/' \
  -e 's/^# \(en_US\.UTF-8.*\)/\1/' \
  -e 's/^# \(es_ES\.UTF-8.*\)/\1/' \
  -e 's/^# \(fr_FR\.UTF-8.*\)/\1/' \
  -e 's/^# \(it_IT\.UTF-8.*\)/\1/' \
  -e 's/^# \(ko_KR\.UTF-8.*\)/\1/' \
  -e 's/^# \(pl_PL\.UTF-8.*\)/\1/' \
  -e 's/^# \(uk_UA\.UTF-8.*\)/\1/' \
  -e 's/^# \(zh_CN\.UTF-8.*\)/\1/' \
  /etc/locale.gen \
  && locale-gen

RUN wget "https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-aarch64.AppImage" \
  && chmod a+x ./appimagetool-aarch64.AppImage \
  && ./appimagetool-aarch64.AppImage appImage.dir
EOF
