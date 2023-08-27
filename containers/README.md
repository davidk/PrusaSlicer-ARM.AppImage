# PrusaSlicer-ARM.AppImage/containers

Utilities and files to support PrusaSlicer ARM AppImage creation in containers. The reason for this is multi-fold:

- Container environments are more consistent and builds can be done across different host operating systems.

- The build avoids contaminating the host system with build dependencies

- Finished builds can be tested without installing all dependencies on the build system

### End user utilities in this directory

#### container-build.sh

Input:

  * Accepts the architecture to build for (aarch64/armhf/all) and the PrusaSlicer version to build for

Output:

  * AppImages are placed in `../PrusaSlicerBuild-$ARCH`, with logging in `../$ARCH-build.log`. Where `$ARCH` is one of `aarch64`, `armhf`.

Options:

```bash
$ ./container-build.sh 
Options: [ aarch64 | armhf | all ] [ version ]
Example: ./container-build.sh aarch64
Example: ./container-build.sh armhf version_2.6.0
Example: ./container-build.sh all
Version is implied to be 'latest' if not provided
```

Building PrusaSlicer (git tag) `version_2.6.0` AppImage for aarch64:

```bash
$ ./container-build.sh aarch64 version_2.6.0
Build version has been set to version_2.6.0 ..
Detected Podman container runtime under arm64 ..
Generating builder images for aarch64..
STEP 1/6: FROM docker.io/balenalib/raspberrypi4-64
STEP 2/6: RUN apt-get update && apt-get install -y wget git jq curl python3-pip
[ .. cut .. ]
```   

Building PrusaSlicer concurrently for both `aarch64` and `armhf`, with the latest github release (pre-releases included).
Note: Only supported under aarch64 systems and tested with a Rock5B (RK3588) using Armbian with 16GB of RAM.

```bash
# This is only tested to work on an aarch64 system with 16GB of RAM
$ ./container-build.sh all
```

#### stage-release.sh

Requirements:

* `~/.config/github-token` with contents `GITHUB_TOKEN="secret"`. The token should have enough permissions in order to create a release on the target repository.

* Build completed by `./container-build.sh` (builds using `./build.sh` are not supported).

Input:

* Accepts the build log and uses `~/.config/github-token` to stage a release on GitHub. This will generate/upload a SHA256SUMS, upload AppImages for aarch64/armhf, fill out the body of text for the release, set the version tag and title. It is up to the end user to determine if the build is a 'pre-release' or 'release' and publish the release/make it visible. 


Output:

* A release on GitHub with assets uploaded (SHA256SUMs, aarch64/armhf AppImages), body, title and version tag filled out using the build log.

Example:

```bash
$ ./stage-release.sh ../aarch64-build.log
```
