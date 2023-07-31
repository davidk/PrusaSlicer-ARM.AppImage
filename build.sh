#!/bin/bash
# build.sh - PrusaSlicer ARM build assistant
#
# This script will assist with installing dependencies, building PrusaSlicer
# and generating an AppImage on a compatible Raspberry Pi OS distribution and armhf/aarch64 system.
#
# How to use:
# $ ./build.sh
# Walks through the process to install dependencies, builds PrusaSlicer and packages the AppImage.
# $ ./build.sh automated
# Does not prompt (defaults to the latest PrusaSlicer version) and executes the steps above.
# $./build.sh dependencies
# Installs dependencies required to build PrusaSlicer and generate an AppImage and exits.
#
# Environmental variables
# BUILD_VERSION="version_2.6.0" - Applies only to automated builds, defaults to empty/latest if not set
#

# PrusaSlicer's GitHub API URL
LATEST_RELEASE="https://api.github.com/repos/prusa3d/PrusaSlicer/releases"

# Dependencies for installation
DEPS_REQUIRED=(libgl1-mesa-dev libglu1-mesa-dev build-essential cmake python3-pip \
	python3-dev python3-setuptools patchelf desktop-file-utils libgdk-pixbuf2.0-dev \
	fakeroot strace fuse libgtk-3-dev m4 zstd screen ninja-build squashfs-tools zsync)

if [[ -v $STY ]] || [[ -z $STY ]]; then
  echo -e '\033[1;36m**** The PrusaSlicer build process can take a long time. Screen or an alternative is advised for long-running terminal sessions. ****\033[0m'
fi

# $0 automated: Run in non-interactive mode. Skips questions and builds latest PrusaSlicer for ARM.
# $0 dependencies: Exit after installing dependencies, intended for container pre-imaging.
if [[ $1 == "automated" ]]; then
  AUTO="yes"
elif [[ $1 == "dependencies" ]]; then
  AUTO="yes"
  DEPS_ONLY="yes"
fi

DPKG_ARCH="$(dpkg --print-architecture)"

echo "Greetings from the PrusaSlicer ARM (${DPKG_ARCH}) AppImage build assistant .."

if [[ "${DPKG_ARCH}" == "armhf" ]]; then
  APPIMAGE_ARCH="armhf"
elif [[ "${DPKG_ARCH}" == "arm64" ]]; then
  APPIMAGE_ARCH="aarch64"
else
  echo "Unknown architecture [arch: ${DPKG_ARCH}]."
  echo "Please update the build assistant to add support."
  exit 1
fi

echo
echo '**********************************************************************************'
echo '* This utility needs your consent to install the following packages for building *'
echo '**********************************************************************************'

for dep in "${DEPS_REQUIRED[@]}"; do
  echo "$dep"
done

echo "---"

if [[ -v AUTO ]]; then
  REPLY="y"
else
  read -p "May I use 'sudo apt-get install -y' to check for and install these dependencies? [N/y] " -n 1 -r
fi

if ! [[ $REPLY =~ ^[Yy]$ ]]; then
  echo "$REPLY"
  echo "Ok. Exiting here."
  exit 1
fi

if ! sudo apt-get install -y "${DEPS_REQUIRED[@]}"; then
  echo "Unable to run 'apt-get install' to install dependencies. Were there any errors displayed above?"
  exit 1
fi

echo
echo "Dependencies installed. Proceeding with installation .."
echo

if ! hash appimage-builder >/dev/null; then
  echo

  if [[ -v AUTO ]]; then
    REPLY="y"
  else
    read -p "appimage-builder and appimage-tool are not installed. They are required for the build process. May I install them? [N/y] " -n 1 -r
  fi

  if ! [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Ok. Exiting here."
    exit 1
  fi

  echo
  echo "Thanks, i'll get both installed .. "

  if ! sudo wget https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-${APPIMAGE_ARCH}.AppImage -O /usr/local/bin/appimagetool; then
    echo "ERROR: Unable to download appimagetool for ${APPIMAGE_ARCH}."
    exit 1
  fi

  sudo chmod +x /usr/local/bin/appimagetool

  if [[ "${DPKG_ARCH}" == "armhf" ]]; then
    # 2023-02-06: Installing an older version to work around upstream issue where interpreter does not get placed into AppImages properly.
    echo "Installing older version of appimage-builder to work around upstream issue for armhf .."

    if ! pip3 install appimage-builder==0.9.2; then
      echo "ERROR: Unable to install appimage-builder v0.9.2 for ${DPKG_ARCH} using pip3 .."
      exit 1
    fi
  elif [[ "${DPKG_ARCH}" == "arm64" ]]; then
    if ! pip3 install git+https://github.com/AppImageCrafters/appimage-builder.git; then
      echo "ERROR: Unable to install appimage-builder using ${DPKG_ARCH} using pip3 .."
      exit 1
    fi
  fi

  if ! hash appimage-builder >/dev/null; then
    echo "ERROR: appimage-builder was installed but could not be found in your PATH: ${PATH}."
    echo "ERROR: hint (to find where appimage-builder was installed to): find ~/ -name appimage-builder"
    echo 'ERROR: hint (to add the path, $HOME/.local/bin to $PATH temporarily): export PATH="$PATH:$HOME/.local/bin"'
    echo "ERROR: Re-run ./$0 if using the above hints"
    exit 1
  fi
fi

if ! hash jq curl >/dev/null; then
  echo

  if [[ -v AUTO ]]; then
    REPLY="y"
  else
    read -p "It looks like jq or curl are not installed. To get the latest version of PrusaSlicer, I need to install jq (to parse JSON output) and curl (to get information from GitHub). May I install these? [N/y] " -n 1 -r
  fi

  if ! [[ $REPLY =~ ^[Yy]$ ]]; then
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

if [[ -v DEPS_ONLY ]]; then
  echo "Dependencies have completed installation, exiting here."
  exit 0
fi

if [[ -v AUTO ]]; then
  REPLY="y"
else
  read -p "May I use 'curl' and 'jq' to check for the latest PrusaSlicer version name? [N/y] " -n 1 -r
fi

if ! [[ $REPLY =~ ^[Yy]$ ]]; then
  echo
  echo "Ok. Exiting here."
  exit 1
else
  echo
  echo "Thanks! I will report back with the version i've found."
  echo
fi

# Grab the latest upstream release version number
LATEST_VERSION="version_$(curl -SsL ${LATEST_RELEASE} | jq -r 'first | .tag_name | select(test("^version_[0-9]{1,2}\\.[0-9]{1,2}\\.[0-9]{1,2}\\-{0,1}(\\w+){0,1}$"))' | cut -d_ -f2)"

if [[ -v AUTO ]]; then
  REPLY="${BUILD_VERSION:=''}"
else
  read -p "The latest version appears to be: ${LATEST_VERSION} .. Would you like to enter a different version (like a git tag 'version_2.1.1' or commit '22d9fcb')? Or continue (leave blank)? " -r
fi

if [[ "${REPLY}" != "" ]]; then
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
if [[ -v AUTO ]]; then
  REPLY="y"
else
  read -n 1 -p "The builder offers a choice between a minimal and full version (saving around 25MB). Building [a]ll versions is the default, but building with the (f)ull or (m)inimal version only is also possible. Please select a version (a)ll [default], (f)ull or (m)inimal? " -r
fi

case $REPLY in
  m|minimal)
    APPIMAGE_BUILD_TYPE="minimal"
    ;;
  f|full)
    APPIMAGE_BUILD_TYPE="full"
    ;;
  *)
    APPIMAGE_BUILD_TYPE="minimal full"
    ;;
esac

echo
echo "Generating [${APPIMAGE_BUILD_TYPE}] build(s) for ${APPIMAGE_ARCH}"
echo

[[ -d "./PrusaSlicer" ]] || git clone https://github.com/prusa3d/PrusaSlicer --single-branch --branch "${LATEST_VERSION}" --depth 1 PrusaSlicer && \
cd PrusaSlicer/deps && \
mkdir -p build && \
cd build && \
cmake .. -DDEP_WX_GTK3=ON && \
cmake --build . && \
cd ../.. && \
mkdir -p build && \
cd build && \
rm -rf AppDir && \
cmake .. \
-GNinja \
-DCMAKE_INSTALL_PREFIX=/usr \
-DCMAKE_PREFIX_PATH="$(pwd)/../deps/build/destdir/usr/local" \
-DSLIC3R_PCH=OFF \
-DSLIC3R_STATIC=ON \
-DSLIC3R_WX_STABLE=OFF \
-DSLIC3R_GTK=3 \
-DCMAKE_BUILD_TYPE=Release

cd ../..

for build_type in ${APPIMAGE_BUILD_TYPE}; do
  cp -f "AppImageBuilder-${APPIMAGE_ARCH}-${build_type}.yml" "AppImageBuilder-${APPIMAGE_ARCH}-${build_type}-${LATEST_VERSION}.yml"
  sed -i "s#%%VERSION%%#${LATEST_VERSION}#g" "AppImageBuilder-${APPIMAGE_ARCH}-${build_type}-${LATEST_VERSION}.yml"
  if [[ "${APPIMAGE_ARCH}" == "armhf" ]]; then
    # 2023-03-06: Older appimage-builder does not have appdir and finds directory OK
    appimage-builder --recipe "AppImageBuilder-${APPIMAGE_ARCH}-${build_type}-${LATEST_VERSION}.yml"
  else
    appimage-builder --appdir ./PrusaSlicer/build/AppDir --recipe "AppImageBuilder-${APPIMAGE_ARCH}-${build_type}-${LATEST_VERSION}.yml"
  fi
  rm -f "AppImageBuilder-${APPIMAGE_ARCH}-${build_type}-${LATEST_VERSION}.yml"
done

echo "Finished build process for PrusaSlicer and arch $(uname -m)."

echo "Here's some information to help with generating and posting a release on GitHub:"

cat <<EOF
${LATEST_VERSION}

PrusaSlicer-${LATEST_VERSION#version_} ARM AppImages

_Prusa Research has released their own [AppImages for ARM](https://github.com/prusa3d/PrusaSlicer/releases/tag/${LATEST_VERSION}). It is advisable to switch to these official builds for the best experience when/if available for your platform._

This release tracks PrusaSlicer's [upstream ${LATEST_VERSION}](https://github.com/prusa3d/PrusaSlicer/releases/tag/${LATEST_VERSION}). AppImages are built using appimage-builder (with PrusaSlicer's dependencies) for broader compatibility at the cost of an increased AppImage size.

### AppImage selection

Run the following in a terminal:

\`\`\`bash
pi@raspberry:~$ uname -m
aarch64
\`\`\`

If the command does not print aarch64 (or arm64), grab an \`armhf\` AppImage.

#### Architectures

##### armhf

armhf distributions are for 32-bit distributions, ex: \`PrusaSlicer-${LATEST_VERSION}-armhf.AppImage\`

##### arm64 / aarch64

These are for 64-bit distributions, ex: \`PrusaSlicer-${LATEST_VERSION}-aarch64.AppImage\`

### How do I run the AppImage?

##### Install dependencies

To use this AppImage, dependencies on the host may be needed (Raspberry Pi OS). Run the following in a terminal to install them:

	sudo apt-get install -y git cmake libboost-dev libboost-regex-dev libboost-filesystem-dev \\
	libboost-thread-dev libboost-log-dev libboost-locale-dev libcurl4-openssl-dev build-essential \\
	pkg-config libtbb-dev zlib1g-dev libcereal-dev libeigen3-dev libnlopt-cxx-dev \\
	libudev-dev libopenvdb-dev libboost-iostreams-dev libgmpxx4ldbl libnlopt-dev \\
	libdbus-1-dev imagemagick libgtk2.0-dev libgtk-3-dev libwxgtk3.0-gtk3-dev fuse libfuse2

After downloading the AppImage and installing dependencies, make the AppImage executable and run the AppImage to launch PrusaSlicer:

32-bit:

    $ chmod +x PrusaSlicer-${LATEST_VERSION}-armhf.AppImage
    $ ./PrusaSlicer-${LATEST_VERSION}-armhf.AppImage

64-bit:

    $ chmod +x PrusaSlicer-${LATEST_VERSION}-aarch64.AppImage
    $ ./PrusaSlicer-${LATEST_VERSION}-aarch64.AppImage

**\`Minimal versions\`** These AppImages include fewer dependencies to reduce size but may not be compatible with older distributions.

All images were built on the Radxa Rock5B platform, optioned with 16GB of RAM and NVMe storage. Additional testing is done on Raspberry Pi 4Bs using Raspberry Pi OS Desktop 64-bit and 32-bit.
EOF
