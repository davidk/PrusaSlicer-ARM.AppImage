#!/bin/bash
# TODO(davidk): Add ways to rewrite certain options before building:
# - version
# - gtk version
# - arch to build/package for

git clone https://github.com/prusa3d/PrusaSlicer --single-branch --branch version_2.4.0-alpha1 --depth 1 PrusaSlicer 

cd PrusaSlicer/deps && \
	mkdir -p build && \
	cd build && \
	CPWD=/home/u/code/PrusaSlicer-ARM.AppImage/PrusaSlicer/build && \
	cmake -G Ninja -DDEP_WX_GTK3=ON .. && \
	ninja && \
	cd ../.. && \
	mkdir -p build && \
	cd build && \
	cmake .. -G Ninja \
	-DCMAKE_INSTALL_PREFIX=/usr \
	-DCMAKE_PREFIX_PATH=/home/u/code/PrusaSlicer-ARM.AppImage/PrusaSlicer/deps/build/destdir/usr/local \
	-DSLIC3R_STATIC=1 \
	-DSLIC3R_PCH=OFF \
	-DSLIC3R_GTK=3 && \
	DESTDIR=AppDir ninja install

# Write out AppImageBuilder.yml

cat > AppImageBuilder.yml <<'EOF'
version: 1

AppDir:
  path: ./AppDir

  app_info:
    id: com.prusa3d.PrusaSlicer
    name: PrusaSlicer
    # TODO(davidk): Replace with PrusaSlicer's icon
    icon: utilities-terminal
    version: version_2.4.0-alpha1
    exec: usr/bin/prusa-slicer

  apt:
    arch: arm64
    allow_unauthenticated: true
    sources:
      - sourceline: 'deb [arch=arm64] http://deb.debian.org/debian buster main contrib non-free'
      - sourceline: 'deb [arch=arm64] http://deb.debian.org/debian-security/ buster/updates main contrib non-free'
      - sourceline: 'deb [arch=arm64] http://deb.debian.org/debian buster-updates main contrib non-free'

    include:
      - python
      - bash 
      - libgail-common
      - libatk-bridge2.0-0
      - libcanberra-gtk-module
      - libgl1-mesa-dri
      - libcgal-dev
      - libboost-dev 
      - libboost-regex-dev 
      - libboost-filesystem-dev
      - libboost-thread-dev
      - libboost-log-dev
      - libboost-locale-dev 
      - libcurl4-openssl-dev
      - libtbb-dev 
      - zlib1g-dev
      - libcereal-dev 
      - libeigen3-dev 
      - libnlopt-cxx-dev 
      - libudev-dev 
      - libopenvdb-dev 
      - libboost-iostreams-dev 
      - libgmpxx4ldbl 
      - libnlopt-dev 
      - libdbus-1-dev 
      - libgtk2.0-dev 
      - libgtk-3-dev 
      - libwxgtk3.0-gtk3-dev 
      - libwxgtk3.0-dev

AppImage: 
  update-information: None
  sign-key: None
  arch: aarch64

EOF

appimage-builder
