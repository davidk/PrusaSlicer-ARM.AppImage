#!/bin/bash
# This is a simple helper to clone the PrusaSlicer-ARM.AppImage repository and log its output for release generation later

git_repo="https://github.com/davidk/PrusaSlicer-ARM.AppImage"
git_branch="$2"
dpkg_arch="$(dpkg --print-architecture)"
build_arch="aarch64"

echo "PrusaSlicer ARM AppImage builder on Kubernetes .."

usage() {
  echo "Note: Version is assumed to be the latest from the API response"
  echo "Options: [ aarch64 ] [ PrusaSlicer-ARM.Appimage git branch ]"
  echo "Example: $0 aarch64 main"
}

if [[ ! -d "/build" ]]; then
  echo "ERROR: /build is not available. This should be provided by the Kubernetes PersistentVolumeClaim."
  echo "Please check that the volume was created successfully by reviewing 'kubectl get events -A -w'. Exiting."
  exit 1;
else
  echo "Switching to /build directory"
  cd /build || exit 1;
fi

# Determine requested architecture. Right now this is only aarch64 but additional support can be added here
case $1 in
  "aarch64")
    build_arch="aarch64"
  ;;
  *)
    echo "ERR: Architecture was not provided"
    usage
    exit 1
  ;;
esac

if [[ "${git_branch}" == "" ]]; then
  echo "ERR: Git branch was not provided." 
  usage
  exit 1;
fi

echo "git_branch:${git_branch},dpkg_arch:${dpkg_arch}"

if [[ ! -d "/build/PrusaSlicer-ARM.AppImage" ]]; then
  echo "Not initialized. Cloning PrusaSlicer-ARM.AppImage .."
  cd /build || exit
  git clone --branch "${git_branch}" "${git_repo}"
fi

echo "Using repository under branch ${git_branch} .."
cd PrusaSlicer-ARM.AppImage || exit 1;

if [[ "${dpkg_arch}" == "arm64" ]]; then
  if [[ "${build_arch}" == "aarch64" ]]; then
    echo "Starting automated build for aarch64. Log output will be directed to ${HOSTNAME}-${build_arch}-k8s-build.log .."
    { time ./build.sh "automated"; } |& sed -e 's/^/aarch64> /;' |& tee "${HOSTNAME}-${build_arch}-k8s-build.log"
  fi
else
  { time ./build.sh "automated"; } |& tee "${HOSTNAME}-${build_arch}-k8s-build.log" &
fi

exit 0