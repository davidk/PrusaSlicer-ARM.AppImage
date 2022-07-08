# PrusaSlicer-ARM.AppImage

PrusaSlicer packaged in an ARM AppImage for the Raspberry Pi 4. Build utilities and [releases](https://github.com/davidk/PrusaSlicer-ARM.AppImage/releases).

**To get a pre-built AppImage**, see [Releases](https://github.com/davidk/PrusaSlicer-ARM.AppImage/releases).

![Screenshot showing PrusaSlicer running on a Pi with system details](prusaslicer-on-pi.png)

# About the AppImage format

An AppImage bundles built software into a single executable file, making its use as simple as downloading and running. This particular AppImage does
not fulfill the entire intent of the format (some dependencies need to be installed on the host), but it allows for PrusaSlicer to be more easily 
used, removed and upgraded by an end user.

# Building your own AppImage

Recommended: Raspberry Pi 4 (or better) with at least 8GB RAM

If for any reason you would like to build your own ARM AppImage, all the files needed for doing so are in this repository. Clone or download this repository, choose your arch (aarch64/armhf) and follow the instructions in the header of the `AppImageBuilder-$ARCH-$TYPE.yml` to build an AppImage similar to the ones provided here. Alternatively, run `./build.sh` (and follow the prompts) to have this done for you.

# Building on Raspberry Pi OS (aarch64)

1. Run through first boot setup

2. Install dependencies for appimage-builder (N.B. screen is optional):

       sudo apt install -y libgl1-mesa-dev libglu1-mesa-dev build-essential cmake python3-pip python3-setuptools \
       patchelf desktop-file-utils libgdk-pixbuf2.0-dev fakeroot strace fuse libgtk-3-dev m4 zstd screen ninja-build

3. Install appimagetool into a location in your $PATH

        sudo wget https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-aarch64.AppImage \
        -O /usr/local/bin/appimagetool

4. Make appimagetool executable

        sudo chmod +x /usr/local/bin/appimagetool

5. Install appimage-builder

        sudo pip3 install appimage-builder

6. Run the build:

        screen
        ./build.sh

When the build finishes, an AppImage will be present in the same directory as the .yml file.
