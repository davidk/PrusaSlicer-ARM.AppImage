#!/bin/bash
echo "Stopping and removing any running builds within podman containers .."
podman kill psarm32 
podman kill psarm64
podman rm psarm32 
podman rm psarm64
echo "Removing PrusaSlicerBuild-* directories .."
rm -rf PrusaSlicerBuild-*
echo "Removing container images .."
podman rmi localhost/psbuilder-armhf 
podman rmi localhost/psbuilder-aarch64
echo "Removing log files .."
rm -f aarch64-build.log armhf-build.log
echo "Done, you may now start a new build .."
