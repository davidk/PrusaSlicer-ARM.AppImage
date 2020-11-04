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
DEPS_REQUIRED="git cmake libboost-dev libboost-regex-dev libboost-filesystem-dev libboost-thread-dev libboost-log-dev libboost-locale-dev libcurl4-openssl-dev libwxgtk3.0-dev build-essential pkg-config libtbb-dev zlib1g-dev libcereal-dev libeigen3-dev libnlopt-cxx-dev libudev-dev libopenvdb-dev libboost-iostreams-dev libnlopt-dev libdbus-1-dev imagemagick"

# URL to the latest libcgal-dev
LIBCGAL_URL="http://raspbian.raspberrypi.org/raspbian/pool/main/c/cgal/libcgal-dev_5.1-1+b1_armhf.deb"


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
echo '******************************************************************************************'
echo '* This package will need to be downloaded and installed (this build requires a later ver) *'
echo '******************************************************************************************'

echo "${LIBCGAL_URL}"

read -p "May I use 'curl' and 'dpkg' to install the Debian package above? [N/y] " -n 1 -r
if ! [[ $REPLY =~ ^[Yy]$ ]]
then
  echo
  echo "Ok. Exiting here."
  exit 1
else
  echo
  echo "Installing package .."
  curl -sSL "${LIBCGAL_URL}" > "${PWD}/${LIBCGAL_URL##*/}"
  if ! sudo dpkg -i "${PWD}/${LIBCGAL_URL##*/}"; then
    read -p "It looks like the installation failed. This is normal on a first attempt. May I run apt install -f to bring in missing dependencies? [N/y] " -n 1 -r

    if ! [[ $REPLY =~ ^[Yy]$ ]]
    then
      echo "$REPLY"
      echo "Ok. Exiting here."
      exit 1
    else
      echo
      sudo apt install -f
    fi
    
  fi
  echo "Done installing package .."
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

[[ -d "./pkg2appimage" ]] || git clone https://github.com/AppImage/pkg2appimage 
OLD_CWD="$(pwd)"
cp ps.yml ./pkg2appimage 
sed -i "s#VERSION_PLACEHOLDER#${LATEST_VERSION}#g" ./pkg2appimage/ps.yml  
cd pkg2appimage || exit
SYSTEM_ARCH="armhf" ./pkg2appimage ps.yml
echo "Finished build process."

echo "Here's some information to help with generating and posting a release on GitHub:"

cat <<EOF
Tag: ${LATEST_VERSION}
-----
This release mirrors PrusaSlicer's [upstream ${LATEST_VERSION}](https://github.com/prusa3d/PrusaSlicer/releases/tag/${LATEST_VERSION}).

To use this AppImage, dependencies on the host are needed (Raspbian Buster):

    \`\`\`sudo apt-get install -y ${DEPS_REQUIRED}\`\`\`

After installation, \`\`\`chmod +x PrusaSlicer-${LATEST_VERSION##version_}-armhf.AppImage\`\`\` and run it.
-----
EOF

cd "${OLD_CWD}" || exit
mv "pkg2appimage/out/PrusaSlicer-.glibc2.28-armhf.AppImage" "pkg2appimage/out/PrusaSlicer-${LATEST_VERSION##version_}-armhf.AppImage"
echo "The final build artifact is available at: pkg2appimage/out/PrusaSlicer-${LATEST_VERSION##version_}-armhf.AppImage"

