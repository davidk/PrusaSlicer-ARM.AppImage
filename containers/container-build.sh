#!/bin/bash
# container-build
#
# This utility is designed to be used on an aarch64 build machine with a container
# runtime to enable builds with fewer effects on a host system (needing to install 
# build-specific packages, etc).
#
# Note: Resource constraints may make building armhf/aarch64 concurrently on an aarch64
# system impossible.
#
# Usage: ./container-build.sh 
# Sequential builds: ./container-build.sh seq
#
# Test system: Radxa Rock 5B + native NVMe storage, optioned w/16GB RAM
#
DPKG_ARCH="$(dpkg --print-architecture)"

if hash podman; then
  echo "Detected Podman container runtime under ${DPKG_ARCH} .."
  RUNTIME="podman"
elif hash docker; then
  echo "Detected Docker container runtime under ${DPKG_ARCH} .."
  RUNTIME="docker"
else 
  echo "Please install podman or docker container tooling on this system to proceed."
  exit 1
fi

cp ../build.sh ./

if [[ "${DPKG_ARCH}" == "armhf" ]]; then
  echo "Generating builder images for armhf .."
  ${RUNTIME} build -t psbuilder-armhf -f Dockerfile.armhf .
elif [[ "${DPKG_ARCH}" == "arm64" ]]; then
  echo "Generating builder images for armhf and aarch64.."
  ${RUNTIME} build -t psbuilder-armhf -f Dockerfile.armhf .

  ${RUNTIME} build -t psbuilder-aarch64 -f Dockerfile.aarch64 .
else
  echo "Unknown architecture [arch: ${DPKG_ARCH}]."
  exit 1
fi

rm -f ./build.sh
cd ../

if [[ "${DPKG_ARCH}" == "armhf" ]]; then

  { time ${RUNTIME} run --device /dev/fuse --cap-add SYS_ADMIN -it -v "${PWD}:/ps:z" psbuilder-armhf |& tee -a containers/armhf-build.log; }
  mv PrusaSlicer PrusaSlicer-armhf

elif [[ "${DPKG_ARCH}" == "arm64" ]]; then

  CURNAME=$(basename "$(pwd)")

  echo "Base directory is ${CURNAME}. Creating ${CURNAME}-armhf and ${CURNAME}-aarch64 for concurrent builds .."
  cd ../

  echo "Creating/copying ${CURNAME}-armhf / ${CURNAME}-aarch64 .."

  rsync -aW "${CURNAME}/" "${CURNAME}-armhf/" &
  rsync -aW "${CURNAME}/" "${CURNAME}-aarch64/" &

  wait

  # aarch64 
  cd "${CURNAME}-aarch64" || exit
  if [[ -d "PrusaSlicer-aarch64" ]]; then
    mv PrusaSlicer-aarch64 PrusaSlicer
  fi

  if [[ $1 == "seq" ]]; then
    { time ${RUNTIME} run -it -v "${PWD}:/ps:z" psbuilder-aarch64 |& tee -a containers/aarch64-build.log && mv PrusaSlicer PrusaSlicer-aarch64; }
  else
    { time ${RUNTIME} run -it -v "${PWD}:/ps:z" psbuilder-aarch64 |& tee -a containers/aarch64-build.log && mv PrusaSlicer PrusaSlicer-aarch64; }&
  fi

  # armhf
  cd "../${CURNAME}-armhf" || exit

  if [[ -d "PrusaSlicer-armhf" ]]; then
    mv PrusaSlicer-armhf PrusaSlicer
  fi

  if [[ $1 == "seq" ]]; then
    { time setarch -B linux32 ${RUNTIME} run --device /dev/fuse --cap-add SYS_ADMIN -it -v "${PWD}:/ps:z" psbuilder-armhf |& tee -a containers/armhf-build.log && mv PrusaSlicer PrusaSlicer-armhf; } 
  else
    { time setarch -B linux32 ${RUNTIME} run --device /dev/fuse --cap-add SYS_ADMIN -it -v "${PWD}:/ps:z" psbuilder-armhf |& tee -a containers/armhf-build.log && mv PrusaSlicer PrusaSlicer-armhf; }&
  fi

  cd ../

  wait

else 
  echo "Unable to build."
  exit 1
fi
