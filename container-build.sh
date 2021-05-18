#!/bin/bash
# Perform setup to build PrusaSlicer in a container

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

if hash podman 2>/dev/null; then
	CONTAINER_BIN="$(command -v podman)"
	echo "Using ${CONTAINER_BIN} for container operations. Doing '${CONTAINER_BIN} unshare chown 1000:1000 on ${BUILD_PS_IN}'"
	${CONTAINER_BIN} unshare chown 1000:1000 -R "${BUILD_PS_IN}"
fi


if ! ${CONTAINER_BIN} build -t keyglitch/prusaslicer-compiler -f Dockerfile.development .; then
	echo "Failed to build container; $?"
	exit;
fi

# Note, this relinks resources to be relative pathed instead of absolute since the inter-container path probably
# differs from the path outside (if the container is run that way)
${CONTAINER_BIN} run -v "${BUILD_PS_IN}":/home/slic3r/PrusaSlicer:Z -i --rm keyglitch/prusaslicer-compiler <<EOF
    cd /home/slic3r/PrusaSlicer \
    && cd deps && mkdir -p deps-build && cd deps-build \
    && cmake -G Ninja .. \
    && ninja \
    && cd ../.. && mkdir -p build && cd build \
    && cmake .. -G Ninja -DCMAKE_PREFIX_PATH="${PWD}../deps/build/destdir/usr/local" -DSLIC3R_STATIC=1 \
    && ninja \
    && rm -f resources \
    && ln -sr ../resources resources \
    && readlink -f ./src/prusa-slicer \
    && exit 0
EOF

