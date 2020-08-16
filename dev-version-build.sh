#!/bin/bash
# dev-version-build.sh - Build PrusaSlicer based on the latest upstream commit

if [[ $# -ne 1 ]]; then
  LATEST_VERSION="master"
else
  LATEST_VERSION="$1"
fi

echo "Building against upstream version: ${LATEST_VERSION}"

[[ -d "./pkg2appimage" ]] || git clone https://github.com/AppImage/pkg2appimage

OLD_CWD="$(pwd)"
cp ps.yml ./pkg2appimage

sed -i "s#VERSION_PLACEHOLDER#${LATEST_VERSION}#g" ./pkg2appimage/ps.yml

cd pkg2appimage || exit
[[ -d "./PrusaSlicer" ]] && rm -rf ./PrusaSlicer

SYSTEM_ARCH="armhf" ./pkg2appimage ps.yml
echo "Finished build process."

cd PrusaSlicer/PrusaSlicer-build || exit
GIT_COMMIT=$(git log -n 1 --pretty=format:"%h")
RELEASE_INFO="${GIT_COMMIT}-$(date +"%Y-%m-%d")"

cd "${OLD_CWD}" || exit
mv "pkg2appimage/out/PrusaSlicer-.glibc2.28-armhf.AppImage" "pkg2appimage/out/PrusaSlicer-dev-${RELEASE_INFO}-armhf.AppImage"
echo "The final build artifact is available at: pkg2appimage/out/PrusaSlicer-dev-${RELEASE_INFO}-armhf.AppImage"

./upload-release.sh "$(readlink -f "pkg2appimage/out/PrusaSlicer-dev-${RELEASE_INFO}-armhf.AppImage")"
