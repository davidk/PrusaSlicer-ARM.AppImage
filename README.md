# PrusaSlicer-ARM.AppImage

PrusaSlicer packaged in an ARM AppImage for the Raspberry Pi 4. Build utilities and releases.

# Tested with

Raspberry Pi 4 (Raspbian Buster), Raspberry Pi 3 (Raspbian Buster)

# Dependencies 

These need to be installed on Raspbian Buster for the AppImage to work.

    sudo apt install -y libboost-dev libboost-regex-dev libboost-filesystem-dev \
    libboost-thread-dev libboost-log-dev libboost-locale-dev libcurl4-openssl-dev \
    libwxgtk3.0-dev libtbb-dev
    
# Building

Run `./build.sh` in the root of the repository. This will install dependencies for building and drop an AppImage into `PrusaSlicer-ARM.AppImage/pkg2appimage/out`.

# Needs to be implemented (contributions welcome)

- [] Version tagging post-build

- [] More dependency bundling with pkg2appimage
