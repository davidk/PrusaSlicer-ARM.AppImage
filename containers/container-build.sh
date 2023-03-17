#!/bin/bash

DPKG_ARCH="$(dpkg --print-architecture)"

if hash podman; then
  echo "Podman container tooling installed."
  RUNTIME="podman"
elif hash docker; then
  echo "Docker container tooling installed."
  RUNTIME="docker"
else 
  echo "Please install podman or docker container tooling on this system to proceed."
  exit 1
fi

if [[ "${DPKG_ARCH}" == "armhf" ]]; then
  ${RUNTIME} build -t psbuilder-armhf -f Dockerfile.armhf .
elif [[ "${DPKG_ARCH}" == "arm64" ]]; then
  ${RUNTIME} build -t psbuilder-armhf -f Dockerfile.armhf .
  ${RUNTIME} build -t psbuilder-aarch64 -f Dockerfile.aarch64 .
else
  echo "Unknown architecture [arch: ${DPKG_ARCH}]."
  exit 1
fi

cd ../

if [[ "${DPKG_ARCH}" == "armhf" ]]; then
  { time ${RUNTIME} run --device /dev/fuse --cap-add SYS_ADMIN -it -v $PWD:/ps:z psbuilder-armhf; } |& tee -a containers/armhf-build.log
  mv PrusaSlicer PrusaSlicer-armhf
elif [[ "${DPKG_ARCH}" == "arm64" ]]; then

  if [[ -d "PrusaSlicer-aarch64" ]]; then
    mv PrusaSlicer-aarch64 PrusaSlicer
  fi

  { time ${RUNTIME} run -it -v $PWD:/ps:z psbuilder-aarch64; } |& tee -a containers/aarch64-build.log
  mv PrusaSlicer PrusaSlicer-aarch64

  if [[ -d "PrusaSlicer-armhf" ]]; then
    mv PrusaSlicer-armhf PrusaSlicer
  fi

  { time setarch -B linux32 ${RUNTIME} run --device /dev/fuse --cap-add SYS_ADMIN -it -v $PWD:/ps:z psbuilder-armhf; } |& tee -a containers/armhf-build.log
  mv PrusaSlicer PrusaSlicer-armhf

else 
  echo "Unable to build."
  exit 1
fi
