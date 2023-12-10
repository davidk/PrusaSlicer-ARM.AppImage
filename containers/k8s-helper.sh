#!/bin/bash
# This is a simple helper to enable execution within a Kubernetes job
# if run without PrusaSlicer being built, it will will proceed
# normally and build PrusaSlicer.
#
# If it detects that PrusaSlicer has already been built or has crashed,
# then this helper will keep the Job around for attachment externally
#

BRANCH="k8s_job"

rebuild=0
rebuild_req=${1:-$rebuild}
built=0
sdir="$(dirname "$(readlink -f "$0")")"

if [[ ! -d "/build" ]]; then
  echo "ERROR: /build is not available"
  exit 1;
else
  echo "Switching to /build directory"
  cd /build
fi

if [[ ! -d "/build/PrusaSlicer-ARM.AppImage" ]]; then
  echo "Not initialized. Cloning PrusaSlicer-ARM.AppImage .."
  git clone --branch $BRANCH https://github.com/davidk/PrusaSlicer-ARM.AppImage
fi

cd PrusaSlicer-ARM.AppImage

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
  ./build.sh "automated"

  echo "Job complete, spinning until process is stopped/removed for examination .."
  tail -f /dev/null
fi
