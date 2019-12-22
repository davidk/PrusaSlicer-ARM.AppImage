#!/bin/bash
# build.sh - PrusaSlicer ARM build assistant
# This script will modify ps.yml and help with installing build/runtime dependencies
# on Debian Buster (on the rPi 4)
#
# Test system specifications: 
# - OS: Debian Buster
# - System: Raspberry Pi 4 (ideally 4GB RAM)
# - Initial libraries required:
#   - jq
#   - curl

echo "Greetings from the PrusaSlicer ARM AppImage build assistant .."

# PrusaSlicer's GitHub API URL
LATEST_RELEASE="https://api.github.com/repos/prusa3d/PrusaSlicer/releases/latest"

# Dependencies fed to apt for installation
DEPS_REQUIRED="git cmake libboost-dev libboost-regex-dev libboost-filesystem-dev libboost-thread-dev libboost-log-dev libboost-locale-dev libcurl4-openssl-dev libwxgtk3.0-dev build-essential pkg-config libtbb-dev zlib1g-dev libcereal-dev libeigen3-dev libnlopt-cxx-dev libudev-dev"

read -p "May I use 'curl' and 'jq' to check for the latest PrusaSlicer version name? [N/y] " -n 1 -r
if ! [[ $REPLY =~ ^[Yy]$ ]]
then
  echo
  echo "Ok. Exiting here."
  exit 1
else
  echo
  echo "Thanks! I will report back with the version i've found."
fi

# Grab the latest upstream release version number
LATEST_VERSION="$(curl -SsL ${LATEST_RELEASE} | jq -r '.tag_name | select(test("^version_[0-9]{1,2}\\.[0-9]{1,2}\\.[0-9]{1,2}\\-{0,1}(\\w+){0,1}$"))' | cut -d_ -f2)"

if [[ -z "${LATEST_VERSION}" ]]; then

  echo "Could not determine the latest version."
  echo
  echo "Possible reasons for this error:"
  echo "* Has release naming changed from previous conventions?"
  echo "* Are curl and jq installed and working as expected?"
  echo "${LATEST_VERSION}"
  exit 1
else
  echo "It looks like the latest version of PrusaSlicer is ${LATEST_VERSION}"
fi


echo
echo '**********************************************************************************'
echo '* This utility needs your consent to install the following packages for building *'
echo '**********************************************************************************'

for dep in $DEPS_REQUIRED; do
  echo "$dep"
done

echo "---"

read -p "May I use 'sudo apt install -y' to check for and install these dependencies? [N/y] " -n 1 -r
if ! [[ $REPLY =~ ^[Yy]$ ]]
then
  echo
  echo "Ok. Exiting here."
  exit 1
else
  echo
  echo "Thanks! The build process should no longer need assistance."
  echo "Feel free to step away for a break (continuing after 5 seconds) ..."
  sleep 5
fi

if sudo apt install -y ${DEPS_REQUIRED}; then
  echo
  echo "Dependencies installed. Proceeding with installation .."
  echo
  [[ -d "./pkg2appimage" ]] || git clone https://github.com/AppImage/pkg2appimage 
  OLD_CWD="$(pwd)"
  cp ps.yml ./pkg2appimage 
  sed -i "s#VERSION_PLACEHOLDER#version_${LATEST_VERSION}#g" ./pkg2appimage/ps.yml  
  cd pkg2appimage 
  SYSTEM_ARCH="armhf" ./pkg2appimage ps.yml
  echo "Finished build process."
  cd $OLD_CWD
  mv "pkg2appimage/out/PrusaSlicer-.glibc2.28-armhf.AppImage" "pkg2appimage/out/PrusaSlicer-${LATEST_VERSION}-armhf.AppImage"
  echo "The final build artifact is available at: pkg2appimage/out/PrusaSlicer-${LATEST_VERSION}-armhf.AppImage"
fi
