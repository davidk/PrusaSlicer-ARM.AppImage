#!/bin/bash
# autobuild.sh - PrusaSlicer ARM build assistant
# 
# This script will assist with installing dependencies building AppImage files on a compatible Raspberry Pi OS
# distribution and system.
#
# Test system specifications: 
# - OS: Raspberry Pi OS
# - System: Raspberry Pi 4 (ideally 8GB RAM for building PrusaSlicer; 4GB with SSD swap if needed) 
#

set +x

# PrusaSlicer's GitHub API URL
LATEST_RELEASE="https://api.github.com/repos/prusa3d/PrusaSlicer/releases/latest"

# Dependencies for installation
DEPS_REQUIRED="libgl1-mesa-dev libglu1-mesa-dev build-essential cmake python3-pip python3-setuptools patchelf desktop-file-utils libgdk-pixbuf2.0-dev fakeroot strace fuse libgtk-3-dev m4 zstd screen ninja-build"
DPKG_ARCH="$(dpkg --print-architecture)"

echo "Greetings from the PrusaSlicer ARM (${DPKG_ARCH}) AppImage build assistant .."

apt-get update

if [[ "${DPKG_ARCH}" == "armhf" ]]; then
  APPIMAGE_ARCH="armhf"
elif [[ "${DPKG_ARCH}" == "arm64" ]]; then
  APPIMAGE_ARCH="aarch64"
else
  echo "Unknown architecture [arch: ${DPKG_ARCH}]."
  echo "Please update the build assistant to add support."
  exit 1
fi

if ! apt-get install -y curl jq wget; then
  echo "Unable to install curl/jq/wget. The error output might have some answers as to what went wrong (above)."
  exit 1
fi

# Grab the latest upstream release version number
LATEST_VERSION="version_$(curl -SsL ${LATEST_RELEASE} | jq -r '.tag_name | select(test("^version_[0-9]{1,2}\\.[0-9]{1,2}\\.[0-9]{1,2}\\-{0,1}(\\w+){0,1}$"))' | cut -d_ -f2)"

if [[ -z "${LATEST_VERSION}" ]]; then
  echo "Could not determine the latest version."
  echo
  echo "Possible reasons for this error:"
  echo "* Has release naming changed from previous conventions?"
  echo "* Are curl and jq installed and working as expected?"
  echo "${LATEST_VERSION}"
  exit 1
else
  echo "I'll be building PrusaSlicer using ${LATEST_VERSION}"
fi

case $1 in
  m|minimal)
    APPIMAGE_BUILD_TYPE="minimal"
    ;;
  *)
    APPIMAGE_BUILD_TYPE="full"
    ;;
esac

echo
echo "AppImageBuilder will use the ${APPIMAGE_BUILD_TYPE} version for $(uname -m)"
echo

echo
echo '**********************************************************************************'
echo '* This utility needs your consent to install the following packages for building *'
echo '**********************************************************************************'

for dep in $DEPS_REQUIRED; do
  echo "$dep"
done

echo "---"

if ! apt-get install -y ${DEPS_REQUIRED}; then
  echo "Unable to run 'apt-get install' to install dependencies. Were there any errors displayed above?"
  exit 1
fi

# Install appimage-builder
wget https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-${APPIMAGE_ARCH}.AppImage -O /usr/local/bin/appimagetool
chmod +x /usr/local/bin/appimagetool
apt-get -y install python3-pip
pip3 install appimage-builder

echo
echo "Dependencies installed. Proceeding with installation .."
echo

echo "Removing previous ./PrusaSlicer build directory if any .."

echo "Building for ${APPIMAGE_ARCH} .."
cp -f AppImageBuilder-${APPIMAGE_ARCH}-${APPIMAGE_BUILD_TYPE}.yml AppImageBuilder-${APPIMAGE_ARCH}-${APPIMAGE_BUILD_TYPE}-${LATEST_VERSION}.yml
sed -i "s#%%VERSION%%#${LATEST_VERSION}#g" AppImageBuilder-${APPIMAGE_ARCH}-${APPIMAGE_BUILD_TYPE}-${LATEST_VERSION}.yml
appimage-builder --recipe AppImageBuilder-${APPIMAGE_ARCH}-${APPIMAGE_BUILD_TYPE}-${LATEST_VERSION}.yml
rm -f AppImageBuilder-${APPIMAGE_ARCH}-${APPIMAGE_BUILD_TYPE}-${LATEST_VERSION}.yml

echo "Finished build process for PrusaSlicer and arch $(uname -m)."

echo "Here's some information to help with generating and posting a release on GitHub:"
  
cat <<EOF
Title: PrusaSlicer-${LATEST_VERSION#version_} ARM AppImages
Tag: ${LATEST_VERSION}
-----
_Prusa Research has officially begun releasing their own [AppImages for ARM](https://github.com/prusa3d/PrusaSlicer/releases/tag/${LATEST_VERSION}). It is advisable to switch to these official builds going forward._
This release mirrors PrusaSlicer's [upstream ${LATEST_VERSION}](https://github.com/prusa3d/PrusaSlicer/releases/tag/${LATEST_VERSION}). AppImages are now built using appimage-builder (with PrusaSlicer's dependencies) for broader compatibility at the cost of an increased AppImage size.
-----
EOF
