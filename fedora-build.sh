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

source "includes/fedora34"

# PrusaSlicer's GitHub API URL
LATEST_RELEASE="https://api.github.com/repos/prusa3d/PrusaSlicer/releases/latest"

echo "Greetings from the PrusaSlicer ARM (${DPKG_ARCH}) AppImage build assistant .."

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
    if ! sudo dnf install -y curl jq; then
      echo "Unable to install curl/jq. The error output might have some answers as to what went wrong (above)."
      exit 1
    fi
  fi
fi

#read -p "May I use 'curl' and 'jq' to check for the latest PrusaSlicer version name? [N/y] " -n 1 -r
#if ! [[ $REPLY =~ ^[Yy]$ ]]
#then
#  echo
#  echo "Ok. Exiting here."
#  exit 1
#else
#  echo
#  echo "Thanks! I will report back with the version i've found."
#  echo
#fi

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

#read -p "May I use 'sudo dnf install -y' to check for and install these dependencies? [N/y] " -n 1 -r
#if ! [[ $REPLY =~ ^[Yy]$ ]]
#then
#  echo "$REPLY"
#  echo "Ok. Exiting here."
#  exit 1
#else
#  echo
#  echo "Thanks! The build process should no longer need assistance."
#  echo "Feel free to step away for a break (continuing after 5 seconds) ..."
#  sleep 5
#fi

if ! sudo dnf install -y ${DEPS_REQUIRED}; then
  echo "Unable to run 'dnf install' to install dependencies. Were there any errors displayed above?"
  exit 1
fi

echo
echo "Dependencies installed. Proceeding with installation .."
echo

[[ -d "./pkg2appimage" ]] || git clone https://github.com/AppImage/pkg2appimage 
OLD_CWD="$(pwd)"
for GTK_VERSION in 2 3; do
  cp ps.yml ./pkg2appimage 
  sed -i "s#VERSION_PLACEHOLDER#${LATEST_VERSION}#g" ./pkg2appimage/ps.yml 
  sed -i "s#PLACEHOLDER_GTK_VERSION#${GTK_VERSION}#g" ./pkg2appimage/ps.yml 

  cd pkg2appimage || exit
  PATH="${OLD_CWD}:${PATH}" SYSTEM_ARCH="$(uname -m)" ./pkg2appimage ps.yml
  echo "Finished build process."
  
  echo "Here's some information to help with generating and posting a release on GitHub:"
  
cat <<EOF
  Tag: ${LATEST_VERSION}
  -----
  This release mirrors PrusaSlicer's [upstream ${LATEST_VERSION}](https://github.com/prusa3d/PrusaSlicer/releases/tag/${LATEST_VERSION}).
  
  To use this AppImage, dependencies on the host are needed (Raspbian Buster):
  
      \`\`\`sudo dnf install -y ${DEPS_REQUIRED}\`\`\`
  
  After installation, \`\`\`chmod +x PrusaSlicer-${LATEST_VERSION##version_}-GTK${GTK_VERSION}-${DPKG_ARCH}.AppImage\`\`\` and run it.
  -----
EOF
  
  cd "${OLD_CWD}" || exit
  mv "pkg2appimage/out/PrusaSlicer-.glibc2.28-${APPIMAGE_ARCH}.AppImage" "pkg2appimage/out/PrusaSlicer-${LATEST_VERSION##version_}-GTK${GTK_VERSION}-${DPKG_ARCH}.AppImage"
  echo "The final build artifact is available at: $(readlink -f ./pkg2appimage/out/PrusaSlicer-${LATEST_VERSION##version_}-GTK${GTK_VERSION}-${DPKG_ARCH}.AppImage)"
done
