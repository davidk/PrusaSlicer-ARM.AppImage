#!/bin/bash

if hash podman; then
  RUNTIME="podman"
elif hash docker; then
  RUNTIME="docker"
else
  echo "Container runtime not detected. Exiting (this is intended to clean up artifacts produced by containers/container-build.sh)."
  exit 1;
fi

echo "Stopping and removing any running builds within podman containers .."
${RUNTIME} kill psarm32 
${RUNTIME} kill psarm64
${RUNTIME} rm psarm32 
${RUNTIME} rm psarm64
echo "Removing PrusaSlicerBuild-* directories .."
rm -rf PrusaSlicerBuild-*
echo "Removing container images .."
${RUNTIME} rmi localhost/psbuilder-armhf 
${RUNTIME} rmi localhost/psbuilder-aarch64
echo "Removing log files .."
rm -f aarch64-build.log armhf-build.log
echo "Done, you may now start a new build .."
