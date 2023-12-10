#!/bin/bash
# This is a simple helper to enable execution within a Kubernetes job
# if run without PrusaSlicer being built, it will will proceed
# normally and build PrusaSlicer.
#
# If it detects that PrusaSlicer has already been built or has crashed,
# then this helper will keep the Job around for attachment externally
#

BRANCH="k8s_job"
DPKG_ARCH="$(dpkg --print-architecture)"

build_arch=""
rebuild=0
rebuild_req=${1:-$rebuild}
built=0

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

cd PrusaSlicer-ARM.AppImage || exit

for appimage in ./PrusaSlicerBuild*/*.AppImage; do
  if [[ -f "${appimage}" ]]; then
    echo "Appimage found at: ${appimage} .."
    built=$((built+1))
  fi
done

if [[ ${built} -gt 0 ]] && [[ "${rebuild_req}" != "rebuild" ]]; then
  echo "There are ${built} Appimages generated.. To stop this container, please kill this process."
  echo "To perform a rebuild, re-run using: '${0} rebuild' [rebuild_req: ${rebuild_req}]"
  echo "Issue a CTRL+C to exit now if running this on the command line."
  tail -f /dev/null
else
  if [[ "${DPKG_ARCH}" == "arm64" ]]; then
    if [[ "${build_arch}" == "aarch64" ]]; then 
      { time ./build.sh "automated"; } |& tee "${HOSTNAME}-${build_arch}-k8s-build.log" &
    fi
 
    # Build on arm64/aarch64, but constrain to armv7l arch
    if [[ "${build_arch}" == "armhf" ]]; then
      { time setarch armv7l -B ./build.sh "automated"; } |& sed -e 's/^/armhf> /;' |& tee -a "${HOSTNAME}-${build_arch}-k8s-build.log" &
    fi
  else
    { time ./build.sh "automated"; } |& tee "${HOSTNAME}-${build_arch}-k8s-build.log" &
  fi

  echo "Spinning until 'tail' process is stopped .."
  tail -f /dev/null
fi
