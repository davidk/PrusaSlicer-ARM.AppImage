#!/bin/bash
set -euo pipefail
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

# Dependencies for building (includes curl and jq for GitHub API access)
DEPS_REQUIRED=(build-essential cmake desktop-file-utils fakeroot fuse git libboost-nowide-dev libgdk-pixbuf2.0-dev \
  libgl1-mesa-dev libglu1-mesa-dev libgtk-3-dev m4 ninja-build patchelf python3-dev python3-pip python3-setuptools \
  screen squashfs-tools strace sudo wget zstd zsync libwebkit2gtk-4.1-dev libwxgtk-media3.2-dev xvfb file binutils \
  patchelf findutils grep sed coreutils strace rsync libibus-1.0-5 texinfo autoconf libtool curl jq ccache)

# Function to prompt user for yes/no input
prompt_user() {
  local prompt_text="$1"
  local reply_var="$2"
  
  if [[ -v AUTO ]]; then
    eval "${reply_var}=y"
  else
    read -p "${prompt_text} [N/y] " -n 1 -r
    eval "${reply_var}=\$REPLY"
  fi
}

# Function to check if user replied yes
user_replied_yes() {
  local reply="$1"
  [[ "${reply}" =~ ^[Yy]$ ]]
}

# Function to download and install a tool
download_tool() {
  local tool_name="$1"
  local url="$2"
  local destination="$3"
  
  echo
  echo "Thanks! Installing ${tool_name} ... "
  
  if [[ ! -e "${destination}" ]]; then
    if ! sudo wget "${url}" -O "${destination}"; then
      echo "ERROR: Unable to download ${tool_name}."
      exit 1
    fi
  fi
  
  sudo chmod +x "${destination}"
}

# Function to validate version string format
validate_version() {
  local version="$1"
  
  # Allow empty string (use latest)
  if [[ -z "${version}" ]]; then
    return 0
  fi
  
  # Valid formats:
  # version_X.Y.Z (e.g., version_2.6.0)
  # version_X.Y.Z-suffix (e.g., version_2.9.2-rc1)
  # commit hash (40 character hex string)
  if [[ "${version}" =~ ^version_[0-9]{1,2}\.[0-9]{1,2}\.[0-9]{1,2}(-[a-zA-Z0-9]+)?$ ]] || \
     [[ "${version}" =~ ^[a-f0-9]{7,40}$ ]]; then
    return 0
  else
    return 1
  fi
}

# Function to sanitize user input
sanitize_input() {
  local input="$1"
  
  # Remove potentially dangerous characters
  # Allow only alphanumeric, dots, hyphens, underscores
  echo "${input}" | sed 's/[^a-zA-Z0-9._-]//g'
}

# Resume capability functions
STATE_FILE=".build_state"

# Function to mark a step as completed
mark_step_completed() {
  local step="$1"
  echo "${step}" >> "${STATE_FILE}"
}

# Function to check if a step is completed
is_step_completed() {
  local step="$1"
  [[ -f "${STATE_FILE}" ]] && grep -q "^${step}$" "${STATE_FILE}"
}

# Function to clear build state (for fresh builds)
clear_build_state() {
  rm -f "${STATE_FILE}"
}

# Function to show resume information
show_resume_info() {
  if [[ -f "${STATE_FILE}" ]]; then
    echo "Found previous build state. Completed steps:"
    while IFS= read -r step; do
      echo "  ✓ ${step}"
    done < "${STATE_FILE}"
    echo
  fi
}

# Function to check available disk space
check_disk_space() {
  local required_gb="$1"
  local path="${2:-.}"

  # Get available space in KB, convert to GB
  local available_kb
  available_kb=$(df -k "${path}" | awk 'NR==2 {print $4}')
  local available_gb=$((available_kb / 1024 / 1024))

  if [[ ${available_gb} -lt ${required_gb} ]]; then
    echo "ERROR: Insufficient disk space!"
    echo "  Required: ${required_gb} GB"
    echo "  Available: ${available_gb} GB"
    echo "  Location: ${path}"
    return 1
  else
    echo "Disk space check: ${available_gb} GB available (${required_gb} GB required) ✓"
    return 0
  fi
}

# Function to configure and setup ccache
setup_ccache() {
  if ! hash ccache >/dev/null 2>&1; then
    echo "Warning: ccache not found, builds will not be cached"
    return 1
  fi

  # Set ccache directory
  export CCACHE_DIR="${HOME}/.ccache"

  # Configure ccache with reasonable defaults
  ccache --set-config=max_size=5G
  ccache --set-config=compression=true
  ccache --set-config=compression_level=6

  echo "ccache configuration:"
  echo "  Cache directory: ${CCACHE_DIR}"
  echo "  Max size: $(ccache --get-config=max_size)"
  echo "  Compression: $(ccache --get-config=compression)"

  return 0
}

# Function to show ccache statistics
show_ccache_stats() {
  if hash ccache >/dev/null 2>&1; then
    echo
    echo "ccache statistics:"
    ccache --show-stats
    echo
  fi
}

# Function to show progress with spinner
show_progress() {
  local message="$1"
  local pid="$2"
  local delay=0.1
  local spin='|/-\'
  
  echo -n "${message} "
  while kill -0 "${pid}" 2>/dev/null; do
    for i in $(seq 0 3); do
      echo -ne "\r${message} [${spin:$i:1}]"
      sleep $delay
    done
  done
  echo -ne "\r${message} [✓]\n"
}

# Function to run command with progress indicator
run_with_progress() {
  local message="$1"
  shift
  local cmd=("$@")
  
  echo "${message}"
  if [[ -v AUTO ]] || [[ ! -t 1 ]]; then
    # In automated mode or non-terminal, just run the command normally
    "${cmd[@]}"
  else
    # In interactive mode with terminal, show progress
    "${cmd[@]}" &
    local cmd_pid=$!
    show_progress "  ${message}" "${cmd_pid}"
    wait "${cmd_pid}"
    return $?
  fi
}

# Function to display help information
show_help() {
  cat << 'EOF'
PrusaSlicer ARM AppImage Build Assistant

USAGE:
    ./build.sh [OPTION]

OPTIONS:
    automated       Run in non-interactive mode using latest PrusaSlicer version
    dependencies    Install system dependencies (including curl/jq) and exit
    buildPrusaSlicerDeps  Build only PrusaSlicer dependencies and exit
    clean           Clear build state and start fresh build
    help, -h, --help     Display this help message and exit

ENVIRONMENT VARIABLES:
    BUILD_VERSION   Specify version for automated builds (e.g., version_2.6.0)
                    Accepts version tags or commit hashes

EXAMPLES:
    ./build.sh                           # Interactive build
    ./build.sh automated                 # Automated build with latest version
    BUILD_VERSION=version_2.6.0 ./build.sh automated  # Automated build with specific version
    ./build.sh dependencies              # Install dependencies only
    ./build.sh clean                     # Clear build state

VERSION FORMATS:
    - version_X.Y.Z (e.g., version_2.6.0)
    - version_X.Y.Z-suffix (e.g., version_2.9.2-rc1)
    - commit hash (7-40 characters, e.g., 22d9fcb)

RESUME CAPABILITY:
    The build process supports resuming interrupted builds. If a build is
    interrupted, simply run the script again and it will skip completed steps.
    Use './build.sh clean' to start a completely fresh build.

EOF
}
  
if [[ -v STY ]] || [[ -z "${STY:-}" ]]; then
  echo -e '\033[1;36m**** The PrusaSlicer build process can take a long time. Screen or an alternative is advised for long-running terminal sessions. ****\033[0m'
fi

# $0 automated: Run in non-interactive mode. Skips questions and builds latest PrusaSlicer for ARM.
# $0 dependencies: Exit after installing dependencies, intended for container pre-imaging.

# Validate command line arguments
if [[ $# -gt 1 ]]; then
  echo "ERROR: Too many arguments. Expected 0 or 1 argument."
  exit 1
fi

if [[ $# -eq 1 ]]; then
  # Sanitize the argument
  ARG="$(sanitize_input "$1")"
  case "${ARG}" in
    "automated")
      AUTO="yes"
      ;;
    "dependencies")
      AUTO="yes"
      DEPS_ONLY="yes"
      ;;
    "buildPrusaSlicerDeps")
      AUTO="yes"
      BUILD_PS_DEPS="yes"
      ;;
    "clean")
      clear_build_state
      echo "Build state cleared. Starting fresh build."
      ;;
    "help"|"--help"|"-h")
      show_help
      exit 0
      ;;
    *)
      echo "ERROR: Invalid argument '${ARG}'"
      echo "Valid arguments: automated, dependencies, buildPrusaSlicerDeps, clean, help"
      echo "Use './build.sh help' for detailed usage information."
      exit 1
      ;;
  esac
fi

# Validate BUILD_VERSION environment variable if set
if [[ -n "${BUILD_VERSION:-}" ]]; then
  SANITIZED_BUILD_VERSION="$(sanitize_input "${BUILD_VERSION}")"
  if ! validate_version "${SANITIZED_BUILD_VERSION}"; then
    echo "ERROR: Invalid BUILD_VERSION environment variable '${BUILD_VERSION}'"
    echo "Valid formats:"
    echo "  - version_X.Y.Z (e.g., version_2.6.0)"
    echo "  - version_X.Y.Z-suffix (e.g., version_2.9.2-rc1)"
    echo "  - commit hash (7-40 characters, e.g., 22d9fcb)"
    exit 1
  fi
  BUILD_VERSION="${SANITIZED_BUILD_VERSION}"
fi

DPKG_ARCH="$(dpkg --print-architecture)"

echo "Greetings from the PrusaSlicer ARM (${DPKG_ARCH}) AppImage build assistant .."

# Check if running as root and warn
if [[ "${EUID}" -eq 0 ]]; then
  echo
  echo -e '\033[1;33mWARNING: Running as root user!\033[0m'
  echo "For security reasons, it's recommended to run this script as a regular user."
  echo "The script will use 'sudo' when elevated privileges are needed."
  echo "Files created as root may have ownership issues for regular users."
  echo
  if [[ ! -v AUTO ]]; then
    read -p "Continue anyway? [N/y] " -n 1 -r
    echo
    if [[ ! "${REPLY}" =~ ^[Yy]$ ]]; then
      echo "Exiting. Please run as a regular user."
      exit 1
    fi
    echo
  else
    echo "Continuing in automated mode..."
    echo
  fi
fi

# Show resume information if available
show_resume_info

# Check disk space before starting build
# PrusaSlicer build requires approximately:
# - 15 GB for dependencies build
# - 10 GB for PrusaSlicer build
# - 5 GB for AppImage creation and temporary files
# Total: ~30 GB minimum recommended, checking for 25 GB to be safe
echo
echo "Checking available disk space..."
if ! check_disk_space 25 "."; then
  echo
  echo "The PrusaSlicer build process requires significant disk space:"
  echo "  - Dependencies: ~15 GB"
  echo "  - PrusaSlicer: ~10 GB"
  echo "  - AppImage: ~5 GB"
  echo
  echo "Please free up disk space and try again."
  exit 1
fi
echo

case "${DPKG_ARCH}" in
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

echo
echo '**********************************************************************************'
echo '* This utility needs your consent to install the following packages for building *'
echo '**********************************************************************************'

if is_step_completed "system_dependencies"; then
  echo "✓ System dependencies already installed (skipping)"
else
  prompt_user "May I use 'sudo apt-get install -y' to check for and install these dependencies (including curl and jq for GitHub API access)?" REPLY

  if ! user_replied_yes "${REPLY}"; then
    echo "${REPLY}"
    echo "Ok. Exiting here."
    exit 1
  fi

  if ! run_with_progress "Installing system dependencies..." sudo apt-get install -y "${DEPS_REQUIRED[@]}"; then
    echo "Unable to run 'apt-get install' to install dependencies. Were there any errors displayed above?"
    exit 1
  fi
  
  mark_step_completed "system_dependencies"
fi

echo
echo "System dependencies installed. Proceeding with installation of Appimage utilities .."
echo


if is_step_completed "appimagetool"; then
  echo "✓ appimagetool already installed (skipping)"
else
  prompt_user "Install appimagetool?" REPLY

  if ! user_replied_yes "${REPLY}"; then
    echo "Ok. Exiting here."
    exit 1
  fi

  APPIMAGETOOL_URL="https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-${APPIMAGE_ARCH}.AppImage"
  download_tool "appimagetool" "${APPIMAGETOOL_URL}" "/usr/local/bin/appimagetool"
  mark_step_completed "appimagetool"
fi

if is_step_completed "lib4bin"; then
  echo "✓ lib4bin already installed (skipping)"
else
  prompt_user "Install lib4bin?" REPLY

  if ! user_replied_yes "${REPLY}"; then
    echo "Ok. Exiting here."
    exit 1
  fi

  LIB4BIN_URL="https://raw.githubusercontent.com/VHSgunzo/sharun/refs/heads/main/lib4bin"
  download_tool "lib4bin" "${LIB4BIN_URL}" "/usr/local/bin/lib4bin"
  mark_step_completed "lib4bin"
fi

echo
echo "Appimage tooling installed. Proceeding with GitHub API access ..."
echo

# curl and jq are now installed with system dependencies, so just verify they're available
if ! hash jq curl >/dev/null 2>&1; then
  echo "ERROR: curl and jq should have been installed with system dependencies but are not available."
  echo "This might indicate a problem with the earlier package installation."
  exit 1
fi

if [[ -v DEPS_ONLY ]]; then
  echo "Dependencies have completed installation, exiting here."
  exit 0
fi

echo "Using curl and jq to check for the latest PrusaSlicer version ..."
echo

# Grab the latest upstream release version number
API_RESPONSE="$(curl -SsL "${LATEST_RELEASE}" 2>/dev/null)"
if [[ -z "${API_RESPONSE}" ]]; then
  echo "ERROR: Failed to fetch version information from GitHub API"
  exit 1
fi

RAW_VERSION="$(echo "${API_RESPONSE}" | jq -r 'first | .tag_name | select(test("^version_[0-9]{1,2}\\.[0-9]{1,2}\\.[0-9]{1,2}\\-{0,1}(\\w+){0,1}$"))' 2>/dev/null)"
if [[ -z "${RAW_VERSION}" ]]; then
  echo "ERROR: Could not parse valid version from GitHub API response"
  exit 1
fi

LATEST_VERSION="version_$(echo "${RAW_VERSION}" | cut -d_ -f2)"

# Validate the parsed version
if ! validate_version "${LATEST_VERSION}"; then
  echo "ERROR: Invalid version format received from API: '${LATEST_VERSION}'"
  exit 1
fi

if [[ -v AUTO ]]; then
  if [[ -n "${BUILD_VERSION:-}" ]]; then
    REPLY="${BUILD_VERSION}"
  else
    REPLY=""
  fi
else
  read -p "The latest version appears to be: ${LATEST_VERSION} .. Would you like to enter a different version (like a git tag 'version_2.A.B' or commit '22d9fcb')? Or continue (leave blank)? " -r
fi

if [[ "${REPLY}" != "" ]]; then
  # Sanitize the input first
  SANITIZED_REPLY="$(sanitize_input "${REPLY}")"
  
  # Validate the sanitized input
  if ! validate_version "${SANITIZED_REPLY}"; then
    echo "ERROR: Invalid version format '${REPLY}'"
    echo "Valid formats:"
    echo "  - version_X.Y.Z (e.g., version_2.6.0)"
    echo "  - version_X.Y.Z-suffix (e.g., version_2.9.2-rc1)" 
    echo "  - commit hash (7-40 characters, e.g., 22d9fcb)"
    exit 1
  fi
  
  echo
  echo "Version will be set to ${SANITIZED_REPLY}"
  LATEST_VERSION="${SANITIZED_REPLY}"
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

if is_step_completed "clone_prusaslicer"; then
  echo "✓ PrusaSlicer repository already cloned (skipping)"
else
  # Clone PrusaSlicer if not already present
  if [[ ! -d "./PrusaSlicer" ]]; then
    if ! run_with_progress "Cloning PrusaSlicer repository..." git clone https://github.com/prusa3d/PrusaSlicer --single-branch --branch "${LATEST_VERSION}" --depth 1 PrusaSlicer; then
      echo "ERROR: Failed to clone PrusaSlicer repository"
      exit 1
    fi
  fi

  cd PrusaSlicer || exit 1

  if ! git checkout "${LATEST_VERSION}"; then
    echo "ERROR: Failed to checkout version ${LATEST_VERSION}"
    exit 1
  fi

  # Apply patches if they exist
  if [[ -d "../patches/${LATEST_VERSION}" ]]; then
    if ! git apply -v ../patches/"${LATEST_VERSION}"/*; then
      echo "ERROR: Failed to apply patches"
      exit 1
    fi
  fi

  cd .. || exit 1
  mark_step_completed "clone_prusaslicer"
fi

if is_step_completed "build_dependencies"; then
  echo "✓ PrusaSlicer dependencies already built (skipping)"
else
  # Setup ccache before building dependencies
  echo
  setup_ccache
  echo

  cd PrusaSlicer/deps || exit 1
  mkdir -p build
  cd build || exit 1

  # Configure CMake with ccache if available
  CMAKE_ARGS=(-DDEP_WX_GTK3=ON -DDEP_DOWNLOAD_DIR="${PWD}/ps-dep-cache")
  if hash ccache >/dev/null 2>&1; then
    CMAKE_ARGS+=(-DCMAKE_C_COMPILER_LAUNCHER=ccache -DCMAKE_CXX_COMPILER_LAUNCHER=ccache)
  fi

  if ! cmake .. "${CMAKE_ARGS[@]}"; then
    echo "ERROR: CMake configuration failed for dependencies"
    exit 1
  fi

  if ! run_with_progress "Building PrusaSlicer dependencies (this may take a while)..." cmake --build . -j "$(nproc)"; then
    echo "ERROR: Failed to build dependencies"
    exit 1
  fi

  cd ../../.. || exit 1
  mark_step_completed "build_dependencies"
fi

if [[ -v BUILD_PS_DEPS ]]; then
  echo "PrusaSlicer dependencies have been built, exiting here."
  exit 0
fi

if is_step_completed "configure_prusaslicer"; then
  echo "✓ PrusaSlicer already configured (skipping)"
else
  cd PrusaSlicer || exit 1
  mkdir -p build
  cd build || exit 1
  rm -rf AppDir

  # Configure CMake with ccache if available
  CMAKE_ARGS=(
    -GNinja
    -DCMAKE_BUILD_TYPE=Release
    -DCMAKE_INSTALL_PREFIX=/usr
    -DCMAKE_PREFIX_PATH="${PWD}/../deps/build/destdir/usr/local"
    -DSLIC3R_GTK=3
    -DSLIC3R_OPENGL_ES=1
    -DSLIC3R_PCH=OFF
    -DSLIC3R_STATIC=ON
  )
  if hash ccache >/dev/null 2>&1; then
    CMAKE_ARGS+=(-DCMAKE_C_COMPILER_LAUNCHER=ccache -DCMAKE_CXX_COMPILER_LAUNCHER=ccache)
  fi

  if ! cmake .. "${CMAKE_ARGS[@]}"; then
    echo "ERROR: CMake configuration failed for PrusaSlicer"
    exit 1
  fi

  cd ../.. || exit 1
  mark_step_completed "configure_prusaslicer"
fi

if is_step_completed "build_prusaslicer"; then
  echo "✓ PrusaSlicer already built (skipping)"
else
  cd PrusaSlicer/build || exit 1

  # Show ccache stats before build
  if hash ccache >/dev/null 2>&1; then
    echo "ccache stats before build:"
    ccache --show-stats --verbose 2>/dev/null | grep -E "(cache hit|cache miss|files in cache)" || ccache --show-stats
    echo
  fi

  if ! run_with_progress "Building PrusaSlicer (using $(nproc) cores, this may take a while)..." cmake --build ./ -j "$(nproc)"; then
    echo "Error building .."
    exit 1
  fi

  # Install to local directory with DESTDIR to avoid requiring root privileges
  export INSTALL_DIR="${PWD}/../../install_dir"
  run_with_progress "Installing PrusaSlicer files to ${INSTALL_DIR}..." env DESTDIR="${INSTALL_DIR}" cmake --build ./ --target install

  # Show ccache stats after build
  show_ccache_stats

  cd ../.. || exit 1
  mark_step_completed "build_prusaslicer"
fi

if is_step_completed "create_appimage"; then
  echo "✓ AppImage already created (skipping)"
else
  cd PrusaSlicer/build || exit 1
  
  set -x
  export PACKAGE="PrusaSlicer"
  export INSTALL_PREFIX="${INSTALL_DIR}/usr"
  export DESKTOP="${INSTALL_PREFIX}/resources/applications/PrusaSlicer.desktop"
  export ICON="${INSTALL_PREFIX}/resources/icons/PrusaSlicer.png"
  export GITHUB_REPOSITORY="davidk/PrusaSlicer-ARM.AppImage"

  ARCH="$(uname -m)"
  export ARCH
  UPINFO="gh-releases-zsync|$(echo ${GITHUB_REPOSITORY} | tr '/' '|')|continuous|*${ARCH}.AppImage.zsync"
  export UPINFO
  export APPIMAGE_EXTRACT_AND_RUN=1

  mkdir -p AppDir && cd AppDir || exit
  mkdir -p shared/lib/             \
          usr/share/applications/  \
          etc/                     \
          usr/resources//

  # Move assets for portability
  cp -av ${INSTALL_PREFIX}/resources/*                              ./usr/resources/
  cp ${INSTALL_PREFIX}/resources/applications/PrusaSlicer.desktop   ./
  cp ${INSTALL_PREFIX}/resources/icons/PrusaSlicer.png              ./

  ln -fs ./usr/share                                   ./share
  ln -fs ./usr/resources                               ./resources
  ln -fs ./shared/lib                                  ./lib

  run_with_progress "Bundling libraries and dependencies..." \
    xvfb-run -a -- /usr/local/bin/lib4bin -p -v -e -s -k  \
          ${INSTALL_PREFIX}/bin/prusa-gcodeviewer       \
          ${INSTALL_PREFIX}/bin/prusa-slicer            \
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

  run_with_progress "Creating AppImage (this may take a while)..." \
    /usr/local/bin/appimagetool \
    --comp zstd \
    --mksquashfs-opt -Xcompression-level --mksquashfs-opt 22 \
    -n -u "${UPINFO}" ./ "${PACKAGE}-${LATEST_VERSION#version_}-${ARCH}-full.AppImage"

  mv ./*.AppImage* ../../../
  
  cd ../../.. || exit 1
  mark_step_completed "create_appimage"
fi

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
