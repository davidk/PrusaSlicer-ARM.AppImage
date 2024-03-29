#!/usr/bin/env bash
# container-build
#
# This utility is designed to be used on an aarch64 build machine with a container
# runtime to enable builds with fewer effects on a host system (needing to install
# build-specific packages, etc).
#
# Note: Resource constraints may make building armhf/aarch64 concurrently on an aarch64
# system impossible.
#
# Usage: ./container-build.sh [aarch64 | armhf | all] [ version ]
#
# Test system: Radxa Rock 5B + native NVMe storage, optioned w/16GB RAM
#

BUILD_AARCH64=""
BUILD_ARMHF=""
BUILD_AMD64=""

# determine build parameters
case $1 in
  "aarch64")
    BUILD_AARCH64="yes"
    unset BUILD_ARMHF
    unset BUILD_AMD64
  ;;
  "armhf")
    BUILD_ARMHF="yes"
    unset BUILD_AARCH64
    unset BUILD_AMD64
  ;;
  "amd64" | "x86_64")
    BUILD_AMD64="yes"
    unset BUILD_AARCH64
    unset BUILD_ARMHF
  ;;
  "all")
    BUILD_AARCH64="yes"
    BUILD_ARMHF="yes"
  ;;
  *)
    echo "Options: [ aarch64 | armhf | [ amd64 | x86_64 ] | all(*) ] [ version ]"
    echo "Example: $0 aarch64"
    echo "Example: $0 armhf version_2.6.0"
    echo "Example: $0 amd64"
    echo "Example: $0 x86_64"
    echo
    echo "Example (this will only build aarch64 and armhf): $0 all"
    echo "Version is implied to be 'latest' if not provided"
    exit 1
  ;;
esac

# Set target build version if one was provided
if [[ -n "${2}" ]]; then
  export BUILD_VERSION="${2}"
  echo "Build version has been set to ${2} .."
fi

if hash podman; then
  echo "Detected Podman container runtime .."
  RUNTIME="podman"
elif hash docker; then
  echo "Detected Docker container runtime .."
  RUNTIME="docker"
else
  echo "Please install podman or docker container tooling on this system to proceed."
  exit 1
fi

cp ../build.sh ./

if [[ -v BUILD_AARCH64 ]]; then
  echo "Generating builder images for aarch64.."
  ${RUNTIME} build -t psbuilder-aarch64 -f Dockerfile.aarch64 .
fi

if [[ -v BUILD_ARMHF ]]; then
  echo "Generating builder images for armhf .."
  time setarch armv7l -B ${RUNTIME} build -t psbuilder-armhf -f Dockerfile.armhf .
fi

if [[ -v BUILD_AMD64 ]]; then
  echo "Generating builder images for amd64.."
  ${RUNTIME} build -t psbuilder-amd64 -f Dockerfile.amd64 .
fi

rm -f ./build.sh
cd ../

if [[ -v BUILD_AARCH64 ]]; then
  if [[ ! -d "PrusaSlicerBuild-aarch64" ]]; then
    git clone . PrusaSlicerBuild-aarch64
  fi

  { time ${RUNTIME} run --rm --name psarm64 --device /dev/fuse --cap-add sys_admin -e build_version -v "${PWD}/PrusaSlicerBuild-aarch64:/ps:z" psbuilder-aarch64; } |& sed -e 's/^/aarch64> /;' |& tee aarch64-build.log &
fi

if [[ -v BUILD_ARMHF ]]; then
  if [[ ! -d "PrusaSlicerBuild-armhf" ]]; then
    git clone . PrusaSlicerBuild-armhf
  fi

  { time setarch armv7l -B ${RUNTIME} run --rm --name psarm32 --device /dev/fuse --cap-add SYS_ADMIN -e BUILD_VERSION -i -v "${PWD}/PrusaSlicerBuild-armhf:/ps:z" psbuilder-armhf; } |& sed -e 's/^/armhf> /;' |& tee -a armhf-build.log &
fi

if [[ -v BUILD_AMD64 ]]; then
  if [[ ! -d "PrusaSlicerBuild-amd64" ]]; then
    git clone . PrusaSlicerBuild-amd64
  fi

   { time ${RUNTIME} run --rm --name psamd64 --device /dev/fuse --cap-add sys_admin -e build_version -v "${PWD}/PrusaSlicerBuild-amd64:/ps:z" psbuilder-amd64; } |& sed -e 's/^/amd64> /;' |& tee amd64-build.log & 
fi

jobs
wait
