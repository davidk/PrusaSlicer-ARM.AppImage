#!/bin/bash
# This is a simple helper to enable execution within a Kubernetes job
# if run without PrusaSlicer being built, it will will proceed
# normally and build PrusaSlicer.
#
# If it detects that PrusaSlicer has already been built or has crashed,
# then this helper will keep the Job around for attachment externally
#

rebuild=0
rebuild_req=${1:-$rebuild}
built=0
sdir="$(dirname "$(readlink -f "$0")")"

for appimage in ../PrusaSlicerBuild*/*.AppImage; do
  if [[ -f "${appimage}" ]]; then
    echo "Appimage found at: ${appimage} .."
    built=$((built+1))
  fi
done

# If the container is started after finishing a build to extract log/AppImages, do not start
# a rebuild, instead spin and warn
if [[ ${built} -gt 0 ]] && [[ "${rebuild_req}" != "rebuild" ]]; then
  echo "There are ${built} Appimages generated.. To stop this container, please kill this process."
  echo "To perform a rebuild, re-run using: '${0} rebuild' [rebuild_req: ${rebuild_req}]"
  echo "Issue a CTRL+C to exit now if running this on the command line."
  tail -f /dev/null
else
  # Figure out the path to execute build.sh in
  if [[ "${PWD}" == "${sdir}" ]]; then
    cd ../
  else
    cd ${sdir} && cd ../
  fi

  exec ./build.sh "automated"
fi
