#!/bin/bash
git clone https://github.com/prusa3d/PrusaSlicer --single-branch --branch version_2.4.0-alpha1 --depth 1 PrusaSlicer 

ORIG_CWD=$(pwd)

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
    version: "1.0"
    exec: usr/bin/prusa-slicer

  apt:
    arch: amd64 
    allow_unauthenticated: true
    sources:
#      - sourceline: 'deb [arch=arm64] http://deb.debian.org/debian buster main contrib non-free'
#      - sourceline: 'deb [arch=arm64] http://deb.debian.org/debian-security/ buster/updates main contrib non-free'
#      - sourceline: 'deb [arch=arm64] http://deb.debian.org/debian buster-updates main contrib non-free'
      - sourceline: 'deb http://deb.debian.org/debian buster main contrib non-free'
      - sourceline: 'deb http://deb.debian.org/debian-security/ buster/updates main contrib non-free'
      - sourceline: 'deb http://deb.debian.org/debian buster-updates main contrib non-free'

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
  arch: x86_64
  #  arch: arm_aarch64

#ingredients:
#  dist: buster
#  script:
#    - [ -d "PrusaSlicer-build" ] || git clone https://github.com/prusa3d/PrusaSlicer --single-branch --branch VERSION_PLACEHOLDER --depth 1 PrusaSlicer-build
#    - cd PrusaSlicer-build && mkdir -p rpi-build && cd rpi-build && cmake .. -DSLIC3R_WX_STABLE=1 -DSLIC3R_FHS=1 -DSLIC3R_GTK=PLACEHOLDER_GTK_VERSION && time make -j$(nproc)
#script:
#  # Workaround when using PrusaSlicer on X-over-SSH (and compiled with GTK3). Basic theme and icon sets.
#  - mkdir -p ./usr/share/mime/packages && cp -a /usr/share/mime/packages/freedesktop.org.xml ./usr/share/mime/packages/
#  - update-mime-database ./usr/share/mime
#  - mkdir -p ./usr/share/icons/Adwaita/ && cp -a /usr/share/icons/Adwaita/* ./usr/share/icons/Adwaita/
#  - mkdir -p ./usr/share/glib-2.0/schemas && cp -a /usr/share/glib-2.0/schemas/* ./usr/share/glib-2.0/schemas
#
#  - mkdir -p ./usr/local/share/PrusaSlicer && cp -a ../PrusaSlicer-build/resources/* ./usr/local/share/PrusaSlicer/
#  - mkdir -p ./usr/bin/ && cp -R ../PrusaSlicer-build/rpi-build/src/prusa-slicer ./usr/bin/
#  - cp ../PrusaSlicer-build/resources/icons/PrusaSlicer.png PrusaSlicer.png
#  - cat > ./PrusaSlicer.desktop <<EOF
#  - [Desktop Entry]
#  - Name=PrusaSlicer
#  - Exec=prusa-slicer
#  - Icon=PrusaSlicer
#  - Terminal=false
#  - Type=Application
#  - Categories=Graphics;3DGraphics;
#  - EOF
EOF

appimage-builder
