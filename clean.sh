#!/bin/bash
echo "Removing PrusaSlicerBuild-* directories .."
rm -rf PrusaSlicerBuild-*
echo "Removing container images .."
podman rmi localhost/psbuilder-armhf 
podman rmi localhost/psbuilder-aarch64
echo "Done, you may now start a new build .."
