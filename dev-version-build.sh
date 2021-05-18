#!/bin/bash
# dev-version-build.sh - Build PrusaSlicer based on the latest upstream commit

if [[ $# -ne 1 ]]; then
  LATEST_VERSION="master"
else
  LATEST_VERSION="$1"
fi

DPKG_ARCH="$(dpkg --print-architecture)"
GTK_VERSION="2"

if [[ "${DPKG_ARCH}" == "armhf" ]]; then
  APPIMAGE_ARCH="armhf"
elif [[ "${DPKG_ARCH}" == "arm64" ]]; then
  # appimagetool releases are named aarch64, instead of arm64 (arm64 is currently synonymous with aarch64)
  APPIMAGE_ARCH="aarch64"
fi

echo "Building against upstream version: ${LATEST_VERSION} for ${DPKG_ARCH}"

[[ -d "./pkg2appimage" ]] || git clone https://github.com/AppImage/pkg2appimage

OLD_CWD="$(pwd)"
cp ps.yml ./pkg2appimage

sed -i "s#VERSION_PLACEHOLDER#${LATEST_VERSION}#g" ./pkg2appimage/ps.yml
sed -i "s#PLACEHOLDER_GTK_VERSION#${GTK_VERSION}#g" ./pkg2appimage/ps.yml 

cd pkg2appimage || exit
[[ -d "./PrusaSlicer" ]] && rm -rf ./PrusaSlicer

SYSTEM_ARCH="${APPIMAGE_ARCH}" ./pkg2appimage ps.yml
echo "Finished build process."

cd PrusaSlicer/PrusaSlicer-build || exit
GIT_COMMIT=$(git log -n 1 --pretty=format:"%h")
RELEASE_INFO="${GIT_COMMIT}-$(date +"%Y-%m-%d")"

cd "${OLD_CWD}" || exit
mv "pkg2appimage/out/PrusaSlicer-.glibc2.28-${DPKG_ARCH}.AppImage" "pkg2appimage/out/PrusaSlicer-dev-${RELEASE_INFO}-${DPKG_ARCH}-GTK${GTK_VERSION}.AppImage"
echo "The final build artifact is available at: pkg2appimage/out/PrusaSlicer-dev-${RELEASE_INFO}-${DPKG_ARCH}-GTK${GTK_VERSION}.AppImage"

./upload-release.sh "$(readlink -f "pkg2appimage/out/PrusaSlicer-dev-${RELEASE_INFO}-${DPKG_ARCH}-GTK${GTK_VERSION}.AppImage")"
