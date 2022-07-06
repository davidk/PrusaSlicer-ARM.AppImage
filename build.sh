#!/bin/bash
# build.sh - PrusaSlicer ARM build assistant
# 
# This script will assist with installing dependencies building AppImage files on a compatible Raspberry Pi OS
# distribution and system.
#
# Test system specifications: 
# - OS: Raspberry Pi OS
# - System: Raspberry Pi 4 (ideally 8GB RAM for building PrusaSlicer; 4GB with SSD swap if needed) 
#

# PrusaSlicer's GitHub API URL
LATEST_RELEASE="https://api.github.com/repos/prusa3d/PrusaSlicer/releases/latest"

# Dependencies for installation
DEPS_REQUIRED="libgl1-mesa-dev libglu1-mesa-dev build-essential cmake python3-pip python3-setuptools patchelf desktop-file-utils libgdk-pixbuf2.0-dev fakeroot strace fuse libgtk-3-dev m4 zstd screen ninja-build"

DPKG_ARCH="$(dpkg --print-architecture)"

echo "Greetings from the PrusaSlicer ARM (${DPKG_ARCH}) AppImage build assistant .."

if [[ -v $STY ]] || [[ -z $STY ]]; then
  echo "The PrusaSlicer build process can take a long time. Screen or an alternative is advised for long-running terminal sessions."
fi


if [[ "${DPKG_ARCH}" == "armhf" ]]; then
  APPIMAGE_ARCH="armhf"
elif [[ "${DPKG_ARCH}" == "arm64" ]]; then
  APPIMAGE_ARCH="aarch64"
else
  echo "Unknown architecture [arch: ${DPKG_ARCH}]."
  echo "Please update the build assistant to add support."
  exit 1
fi

if ! hash jq curl >/dev/null; then
  echo
  read -p "It looks like jq or curl are not installed. To get the latest version of PrusaSlicer, I need to install jq (to parse JSON output) and curl (to get information from GitHub). May I install these? [N/y] " -n 1 -r
  if ! [[ $REPLY =~ ^[Yy]$ ]]
  then
    echo "Ok. Exiting here."
    exit 1
  else
    echo
    echo "Thanks, i'll get these installed .."
    if ! sudo apt-get install -y curl jq; then
      echo "Unable to install curl/jq. The error output might have some answers as to what went wrong (above)."
      exit 1
    fi
  fi
fi

read -p "May I use 'curl' and 'jq' to check for the latest PrusaSlicer version name? [N/y] " -n 1 -r
if ! [[ $REPLY =~ ^[Yy]$ ]]
then
  echo
  echo "Ok. Exiting here."
  exit 1
else
  echo
  echo "Thanks! I will report back with the version i've found."
  echo
fi

# Grab the latest upstream release version number
LATEST_VERSION="version_$(curl -SsL ${LATEST_RELEASE} | jq -r '.tag_name | select(test("^version_[0-9]{1,2}\\.[0-9]{1,2}\\.[0-9]{1,2}\\-{0,1}(\\w+){0,1}$"))' | cut -d_ -f2)"

read -p "The latest version appears to be: ${LATEST_VERSION} .. Would you like to enter a different version (like a git tag 'version_2.1.1' or commit '22d9fcb')? Or continue (leave blank)? " -r
if [[ "${REPLY}" != "" ]]
then
  echo
  echo "Version will be set to ${REPLY}"
  LATEST_VERSION="${REPLY}"
else
  echo
  echo "Okay, continuing with the version from the API."
fi

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

echo
echo '**********************************************************************************'
echo '* This utility needs your consent to install the following packages for building *'
echo '**********************************************************************************'

for dep in $DEPS_REQUIRED; do
  echo "$dep"
done

echo "---"

read -p "May I use 'sudo apt-get install -y' to check for and install these dependencies? [N/y] " -n 1 -r
if ! [[ $REPLY =~ ^[Yy]$ ]]
then
  echo "$REPLY"
  echo "Ok. Exiting here."
  exit 1
else
  echo
  echo "Thanks! The build process should no longer need assistance."
  echo "Feel free to step away for a break (continuing after 5 seconds) ..."
  sleep 5
fi

if ! sudo apt-get install -y ${DEPS_REQUIRED}; then
  echo "Unable to run 'apt-get install' to install dependencies. Were there any errors displayed above?"
  exit 1
fi

echo
echo "Dependencies installed. Proceeding with installation .."
echo

echo "Removing previous ./PrusaSlicer build directory if any .."

echo "Building for ${APPIMAGE_ARCH} .."
cp -f AppImageBuilder-${APPIMAGE_ARCH}-minimal.yml AppImageBuilder-${APPIMAGE_ARCH}-minimal-${LATEST_VERSION}.yml
sed -i "s#%%VERSION%%#${LATEST_VERSION}#g" AppImageBuilder-${APPIMAGE_ARCH}-minimal-${LATEST_VERSION}.yml
appimage-builder --recipe AppImageBuilder-${APPIMAGE_ARCH}-minimal-${LATEST_VERSION}.yml
rm -f AppImageBuilder-${APPIMAGE_ARCH}-minimal-${LATEST_VERSION}.yml

echo "Finished build process."

echo "Here's some information to help with generating and posting a release on GitHub:"
  
cat <<EOF
Title: PrusaSlicer-${LATEST_VERSION#version_} ARM AppImages
Tag: ${LATEST_VERSION}
-----
_Prusa Research has officially begun releasing their own [AppImages for ARM](https://github.com/prusa3d/PrusaSlicer/releases/tag/${LATEST_VERSION}). It is advisable to switch to these official builds going forward._
This release mirrors PrusaSlicer's [upstream ${LATEST_VERSION}](https://github.com/prusa3d/PrusaSlicer/releases/tag/${LATEST_VERSION}). AppImages are now built using appimage-builder (with PrusaSlicer's dependencies) for broader compatibility at the cost of an increased AppImage size.
-----
EOF
