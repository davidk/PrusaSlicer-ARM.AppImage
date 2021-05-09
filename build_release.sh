#! /usr/bin/env bash

function installDeps () {
  export DEBIAN_FRONTEND=noninteractive

  apt update
  apt install -y \
    automake \
    bison \
    build-essential \
    cmake \
    cmake \
    curl \
    flex \
    g++ \
    gettext \
    git \
    imagemagick \
    jq \
    libboost-dev \
    libboost-filesystem-dev  \
    libboost-iostreams-dev \
    libboost-locale-dev \
    libboost-log-dev \
    libboost-regex-dev \
    libboost-system-dev  \
    libboost-test-dev \
    libboost-thread-dev \
    libcereal-dev \
    libcurl4-openssl-dev \
    libdbus-1-dev \
    libeigen3-dev \
    libglm-dev \
    libgmpxx4ldbl \
    libgtk-3-dev \
    libgtk2.0-dev \
    libnlopt-cxx-dev \
    libnlopt-dev \
    liboce-ocaf-dev \
    libopenvdb-dev \
    libtbb-dev \
    libtool \
    libudev-dev \
    libwxbase3.0-dev \
    libwxgtk* \
    pkg-config \
    swig \
    wget \
    zlib1g-dev

  apt install -f -y
}

function fakeOsVersion () {
  cat <<EOF > uname
#! /usr/bin/env bash
echo "unknown"
EOF

chmod +x uname

}

function buildPkg () {
  if [[ "${DPKG_ARCH}" == "armhf" ]]; then
    export LIBCGAL_URL="http://raspbian.raspberrypi.org/raspbian/pool/main/c/cgal/libcgal-dev_5.2-3_armhf.deb"
  elif [[ "${DPKG_ARCH}" == "arm64" ]]; then
    export LIBCGAL_URL="http://ftp.debian.org/debian/pool/main/c/cgal/libcgal-dev_5.2-3_arm64.deb"
  else
    echo "Unknown architecture [arch: ${DPKG_ARCH}]. could not figure out which LIGCGAL library was needed."
    echo "Please update the build assistant to add support!"
    exit 1
  fi

  curl -sSL "${LIBCGAL_URL}" > "${PWD}/${LIBCGAL_URL##*/}"
  if ! dpkg -i -E "${PWD}/${LIBCGAL_URL##*/}"; then
    apt install -f -y
  fi

  for dep in $DEPS_REQUIRED; do
    echo "$dep"
  done

  apt-get install -y ${DEPS_REQUIRED}
  [[ -d "./pkg2appimage" ]] || git clone https://github.com/AppImage/pkg2appimage
  OLD_CWD="$(pwd)"
  APPIMAGE_ARCH="aarch64"
  for GTK_VERSION in 3; do
    cp ps.yml ./pkg2appimage
    sed -i "s#VERSION_PLACEHOLDER#${LATEST_VERSION}#g" ./pkg2appimage/ps.yml
    sed -i "s#PLACEHOLDER_GTK_VERSION#${GTK_VERSION}#g" ./pkg2appimage/ps.yml

    cd pkg2appimage || exit
    PATH="${OLD_CWD}:${PATH}" SYSTEM_ARCH="${APPIMAGE_ARCH}" ./pkg2appimage ps.yml
    echo "Finished build process."
  done
}

function postBuild () {
  chmod +x pkg2appimage/PrusaSlicer/PrusaSlicer.AppDir/AppRun
  chmod +x pkg2appimage/PrusaSlicer/PrusaSlicer.AppDir/usr/bin/prusa-slicer
}

installDeps
fakeOsVersion
buildPkg
postBuild
