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
# $ ./build.sh dependencies
# Installs dependencies required to build PrusaSlicer and generate an AppImage and exits.
#
# Environmental variables
# BUILD_VERSION="version_2.6.0" - Applies only to automated builds, defaults to empty/latest if not set
#

# PrusaSlicer's GitHub API URL
LATEST_RELEASE="https://api.github.com/repos/prusa3d/PrusaSlicer/releases"

# Dependencies for building
DEPS_REQUIRED=(build-essential cmake desktop-file-utils fakeroot fuse git libboost-nowide-dev libgdk-pixbuf2.0-dev \
  libgl1-mesa-dev libglu1-mesa-dev libgtk-3-dev m4 ninja-build patchelf python3-dev python3-pip python3-setuptools \
  screen squashfs-tools strace sudo wget zstd zsync libwebkit2gtk-4.1-dev libwxgtk-media3.2-dev xvfb file binutils \
  patchelf findutils grep sed coreutils strace rsync)
  
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
elif [[ $1 == "buildPrusaSlicerDeps" ]]; then
  AUTO="yes"
  BUILD_PS_DEPS="yes"
fi

DPKG_ARCH="$(dpkg --print-architecture)"

echo "Greetings from the PrusaSlicer ARM (${DPKG_ARCH}) AppImage build assistant .."

case ${DPKG_ARCH} in
  "armhf")
    APPIMAGE_ARCH="armhf"
    ;;
  "arm64")
    APPIMAGE_ARCH="aarch64"
    ;;
  "amd64")
    APPIMAGE_ARCH="x86_64"
    ;;
  *)
    echo "Unknown architecture [arch: ${DPKG_ARCH}]."
    echo "Please update the build assistant to add support."
    exit 1
    ;;
esac

for dep in "${DEPS_REQUIRED[@]}"; do
  echo "$dep"
done

echo "---"

if [[ -v AUTO ]]; then
  REPLY="y"
else
  # 
  echo
  echo '**********************************************************************************'
  echo '* This utility needs your consent to install the following packages for building *'
  echo '**********************************************************************************'
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
echo "System dependencies installed. Proceeding with installation of Appimage utilities .."
echo


if [[ -v AUTO ]]; then
  REPLY="y"
else
  read -p "Install appimagetool? [N/y] " -n 1 -r
fi

if ! [[ $REPLY =~ ^[Yy]$ ]]; then
  echo "Ok. Exiting here."
  exit 1
fi

echo
echo "Thanks! Installing appimagetool ... "

if [[ ! -e "/usr/local/bin/appimagetool" ]]; then
  if ! sudo wget https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-${APPIMAGE_ARCH}.AppImage -O /usr/local/bin/appimagetool; then
    echo "ERROR: Unable to download appimagetool for ${APPIMAGE_ARCH}."
    exit 1
  fi
fi

sudo chmod +x /usr/local/bin/appimagetool

if [[ -v AUTO ]]; then
  REPLY="y"
else
  read -p "Install lib4bin? [N/y] " -n 1 -r
fi

if ! [[ $REPLY =~ ^[Yy]$ ]]; then
  echo "Ok. Exiting here."
  exit 1
fi

echo
echo "Thanks! Installing lib4bin ... "

if [[ ! -e "/usr/local/bin/lib4bin" ]]; then
  if ! sudo wget https://raw.githubusercontent.com/VHSgunzo/sharun/refs/heads/main/lib4bin -O /usr/local/bin/lib4bin; then
    echo "ERROR: Unable to download lib4bin for ${APPIMAGE_ARCH}."
    exit 1
  fi
fi

sudo chmod +x /usr/local/bin/lib4bin

echo
echo "Appimage tooling installed. Installing utilities to interact with Github's API ..."
echo

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
  if [[ -n "${BUILD_VERSION}" ]]; then
    REPLY="${BUILD_VERSION}"
  else
    REPLY=""
  fi
else
  read -p "The latest version appears to be: ${LATEST_VERSION} .. Would you like to enter a different version (like a git tag 'version_2.A.B' or commit '22d9fcb')? Or continue (leave blank)? " -r
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

[[ -d "./PrusaSlicer" ]] || git clone https://github.com/prusa3d/PrusaSlicer --single-branch --branch "${LATEST_VERSION}" --depth 1 PrusaSlicer && \
cd PrusaSlicer && \
git checkout "${LATEST_VERSION}" && \
[[ -d "../patches/${LATEST_VERSION}" ]]; git apply -v ../patches/"${LATEST_VERSION}"/*; \
cd deps && \
mkdir -p build && \
cd build && \
cmake .. -DDEP_WX_GTK3=ON -DDEP_DOWNLOAD_DIR="${PWD}/ps-dep-cache" && \
cmake --build .

if [[ -v BUILD_PS_DEPS ]]; then
  echo "PrusaSlicer dependencies have been built, exiting here."
  exit 0
fi

cd ../.. && \
mkdir -p build && \
cd build && \
rm -rf AppDir && \
cmake .. \
-GNinja \
-DCMAKE_BUILD_TYPE=Release \
-DCMAKE_INSTALL_PREFIX=/usr \
-DCMAKE_PREFIX_PATH="${PWD}/../deps/build/destdir/usr/local" \
-DSLIC3R_GTK=3 \
-DSLIC3R_OPENGL_ES=1 \
-DSLIC3R_PCH=OFF \
-DSLIC3R_STATIC=ON

cd ../..

mkdir -p PrusaSlicer/build
cd PrusaSlicer/build || exit
if ! cmake --build ./ --target install -j "$(nproc)"; then
  echo "Error building .." 
  exit 1;
fi

# Build AppImage based off of system-level install
make install

set -x
export PACKAGE="PrusaSlicer"
export DESKTOP="/usr/resources/applications/PrusaSlicer.desktop"
export ICON="/usr/resources/icons/PrusaSlicer.png"
export GITHUB_REPOSITORY="davidk/PrusaSlicer-ARM.AppImage"
UPINFO="gh-releases-zsync|$(echo ${GITHUB_REPOSITORY} | tr '/' '|')|continuous|*${ARCH}.AppImage.zsync"
export UPINFO

ARCH="$(uname -m)"
export ARCH
export APPIMAGE_EXTRACT_AND_RUN=1

export APPIMAGETOOL="https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-${ARCH}.AppImage"
export LIB4BN="https://raw.githubusercontent.com/VHSgunzo/sharun/refs/heads/main/lib4bin"

mkdir -p AppDir && cd AppDir || exit
mkdir -p shared/lib/             \
        usr/share/applications/  \
        etc/                     \
        usr/resources//

# Move assets for portability
cp -av /usr/resources/*                              ./usr/resources/
cp /usr/resources/applications/PrusaSlicer.desktop   ./
cp /usr/resources/icons/PrusaSlicer.png              ./

ln -fs ./usr/share                                   ./share
ln -fs ./usr/resources                               ./resources
ln -fs ./shared/lib                                  ./lib

xvfb-run -a -- /usr/local/bin/lib4bin -p -v -e -s -k  \
        /usr/bin/prusa-gcodeviewer                    \
        /usr/bin/prusa-slicer                         \
        /usr/lib/"${ARCH}"-linux-gnu/webkit2gtk-4.1/* \
        /usr/lib/"${ARCH}"-linux-gnu/libnss*          \
        /usr/lib/"${ARCH}"-linux-gnu/gio/*            \
        /usr/share/glib-2.0                           \
        /usr/share/glvnd/*                            \
        /usr/lib/"${ARCH}"-linux-gnu/dri/* 

cp /usr/bin/OCCTWrapper.so ./bin/

# Create environment
cat > .env <<'EOF'
SHARUN_WORKING_DIR=${SHARUN_DIR}
LIBGL_DRIVERS_PATH=${SHARUN_DIR}/shared/lib/dri
GSETTINGS_BACKEND=memory
unset LD_LIBRARY_PATH
unset LD_PRELOAD
EOF

wget -c "https://github.com/VHSgunzo/sharun/releases/download/v0.4.3/sharun-$(uname -m)-upx" -O ./sharun || true
chmod +x ./sharun && ln ./sharun ./AppRun
./sharun -g || true 

/usr/local/bin/appimagetool \
  --comp zstd \
  --mksquashfs-opt -Xcompression-level --mksquashfs-opt 22 \
  -n -u "${UPINFO}" ./ "${PACKAGE}-${LATEST_VERSION#version_}-${ARCH}-full.AppImage"

mv ./*.AppImage* ../../../

echo "Finished build process for PrusaSlicer and arch ${ARCH}. AppImage is: PrusaSlicer-${LATEST_VERSION#version_}-${ARCH}-full.AppImage"

echo "Here is some information to help with generating and posting a release on GitHub:"

export LATEST_VERSION

cat <<EOF
${LATEST_VERSION}

PrusaSlicer-${LATEST_VERSION#version_} ARM AppImages

This release tracks PrusaSlicer's upstream ${LATEST_VERSION}](https://github.com/prusa3d/PrusaSlicer/releases/tag/${LATEST_VERSION}). 
AppImages have been built using sharun and appimagetool (with PrusaSlicer's dependencies).

### How do I run the AppImage?

After downloading the AppImage and installing dependencies, use the terminal to make the AppImage executable and run:

    $ chmod +x PrusaSlicer-${LATEST_VERSION}-aarch64.AppImage
    $ ./PrusaSlicer-${LATEST_VERSION}-aarch64.AppImage

EOF
