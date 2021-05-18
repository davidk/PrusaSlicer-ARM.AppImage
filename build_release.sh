#! /usr/bin/env bash

function installDeps () {
  export DEBIAN_FRONTEND=noninteractive
  source "/app/includes/ubuntu-actions"

  apt update
  apt install -y ${GITHUB_ACTIONS_UBUNTU_DEPS}
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
  APPIMAGE_ARCH="aarch64"
  source "/app/includes/libcgal_${DPKG_ARCH}"
      
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
  for GTK_VERSION in 3; do
    cp ps.yml ./pkg2appimage
    sed -i "s#VERSION_PLACEHOLDER#${LATEST_VERSION}#g" ./pkg2appimage/ps.yml
    sed -i "s#PLACEHOLDER_GTK_VERSION#${GTK_VERSION}#g" ./pkg2appimage/ps.yml

    cd pkg2appimage || exit
    PATH="${OLD_CWD}:${PATH}" SYSTEM_ARCH="${APPIMAGE_ARCH}" ./pkg2appimage ps.yml
    echo "Finished build process."
  done
}

installDeps
fakeOsVersion
buildPkg
