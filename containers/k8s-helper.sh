#!/bin/bash
# This is a simple helper to enable execution within a Kubernetes job.
# If run without PrusaSlicer already being built, it will proceed to
# build PrusaSlicer.
#
# If it detects that PrusaSlicer has already been built or has crashed,
# then this helper will keep the Job alive for attachment with a shell
# for debugging
#
# Examples (to be added inside a Job definition's cmd, etc):
#
# Building armhf AppImages on an arm64/aarch64 platform
# $ setarch armv7l -B ./k8s-helper.sh armhf
#
# Building aarch64 AppImages on an amd64/aarch64 platform
# $ ./k8s-helper.sh aarch64
#

BRANCH="k8s_job"
DPKG_ARCH="$(dpkg --print-architecture)"

build_arch=""
rebuild=0
rebuild_req=${1:-$rebuild}
built=0

echo "PrusaSlicer ARM AppImage builder on Kubernetes .."
echo "BRANCH:${BRANCH},DPKG_ARCH:${DPKG_ARCH},rebuild_req:${rebuild_req}"

if [[ ! -d "/build" ]]; then
  echo "ERROR: /build is not available. This should be provided by the Kubernetes PersistentVolumeClaim."
  echo "Please check that the volume was created successfully by reviewing 'kubectl get events -A -w'. Exiting."
  exit 1;
else
  echo "Switching to /build directory"
  cd /build || exit
fi

# Determine requested architecture
case $1 in
  "aarch64")
    build_arch="aarch64"
  ;;
  "armhf")
    build_arch="armhf"
  ;;
  "x86_64")
    build_arch="x86_64"
  ;;
  *)
     echo "Version is assumed to be the latest from the API response"
     echo "Options: [ aarch64 | armhf | x86_64 ]"
     echo "Example: $0 aarch64"
     echo "Example: $0 armhf"
     echo "Example: $0 x86_64"
     echo
     exit 1
  ;;
esac

if [[ ! -d "/build/PrusaSlicer-ARM.AppImage" ]]; then
  echo "Not initialized. Cloning PrusaSlicer-ARM.AppImage .."
  git clone --branch $BRANCH https://github.com/davidk/PrusaSlicer-ARM.AppImage
fi

echo "Using repository under branch $BRANCH .."
cd PrusaSlicer-ARM.AppImage || exit

for appimage in ./PrusaSlicerBuild*/*.AppImage; do
  if [[ -f "${appimage}" ]]; then
    echo "Appimage found at: ${appimage} .."
    built=$((built+1))
  fi
done

if [[ ${built} -gt 0 ]] && [[ "${rebuild_req}" != "rebuild" ]]; then
  echo "There are ${built} AppImages generated.. To stop this container, please kill this process."
  echo "To perform a rebuild, re-run using: '${0} rebuild' [rebuild_req: ${rebuild_req}]"
  echo "Issue a CTRL+C to exit now if running this on the command line."
  tail -f /dev/null
else
  echo "Found ${built} AppImages have been built so far. Proceeding to build."
  if [[ "${DPKG_ARCH}" == "arm64" ]] || [[ "${DPKG_ARCH}" == "armhf" ]]; then
    if [[ "${build_arch}" == "aarch64" ]]; then
      echo "Starting automated build for aarch64 .."
      { time ./build.sh "automated" || tail -f /dev/null; } |& sed -e 's/^/aarch64> /;' |& tee "${HOSTNAME}-${build_arch}-k8s-build.log"
    fi

    # Build on arm64/aarch64, but constrain to armv7l arch
    if [[ "${build_arch}" == "armhf" ]]; then
      echo "Installing dependencies for armhf .."
      # Building pip requirements needs a Rust toolchain and an OpenSSL dependency
      curl https://sh.rustup.rs -sSf | sh -s -- -y
      # shellcheck source=/dev/null
      source "$HOME/.cargo/env"
      apt-get update && apt-get install -y librust-openssl-dev
      echo "Starting automated build for armhf .."
      { time setarch armv7l -B ./build.sh "automated" || tail -f /dev/null; } |& sed -e 's/^/armhf> /;' |& tee -a "${HOSTNAME}-${build_arch}-k8s-build.log"
    fi
  else
    { time ./build.sh "automated" || tail -f /dev/null; } |& tee "${HOSTNAME}-${build_arch}-k8s-build.log" &
  fi
fi

exit 0
