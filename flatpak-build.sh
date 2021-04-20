#!/bin/bash
# build.sh - PrusaSlicer ARM build assistant
# This script will modify and help with installing build/runtime dependencies
#
# Build configuration/hardware:
# - Raspberry Pi 4, 8GB 
# - ~2GB of swap disk added
# - Ubuntu 20.10 Groovy (aarch64)
#

# URL to the PrusaSlicer repository
PS_REPO="https://github.com/prusa3d/PrusaSlicer"

# PrusaSlicer's GitHub API URL
LATEST_RELEASE="https://api.github.com/repos/prusa3d/PrusaSlicer/releases/latest"

# Dependencies fed to apt for installation
DEPS_REQUIRED="git flatpak flatpak-builder"

DPKG_ARCH="$(dpkg --print-architecture)"

echo "Greetings from the PrusaSlicer (${DPKG_ARCH}) flatpak build assistant .."

if ! hash jq curl >/dev/null; then
  echo
  read -p "It looks like jq or curl are not installed. To get the latest version of PrusaSlicer, I need to install jq (to parse JSON output) and curl (to get information from GitHub). May I install these? [N/y] " -n 1 -r
  if ! [[ $REPLY =~ ^[Yy]$ ]]
  then
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

read -p "May I use 'curl' and 'jq' to check for the latest PrusaSlicer version name? [N/y] " -n 1 -r
if ! [[ $REPLY =~ ^[Yy]$ ]]
then
  echo
  echo "Ok. Exiting here."
  exit 1
else
  echo
  echo "Thanks! I will report back with the version i've found."
  echo
fi

# Grab the latest upstream release version number
LATEST_VERSION="version_$(curl -SsL ${LATEST_RELEASE} | jq -r '.tag_name | select(test("^version_[0-9]{1,2}\\.[0-9]{1,2}\\.[0-9]{1,2}\\-{0,1}(\\w+){0,1}$"))' | cut -d_ -f2)"

read -p "The latest version appears to be: ${LATEST_VERSION} .. Would you like to enter a different version (like a git tag 'version_2.1.1' or commit '22d9fcb')? Or continue (leave blank)? " -r
if [[ "${REPLY}" != "" ]]
then
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
echo '**************************************************************'
echo '* This utility needs your consent to install the flatpak SDK *'
echo '**************************************************************'

read -p "May I use 'sudo flatpak install -y org.freedesktop.Sdk/aarch64/20.08 org.freedesktop.Platform/aarch64/20.08' to install? [N/y] " -n 1 -r
if ! [[ $REPLY =~ ^[Yy]$ ]]
then
  echo "$REPLY"
  echo "Ok. Exiting here."
  exit 1
else
  echo
  echo "Installing flatpak dependencies .."
fi

if ! sudo flatpak install -y org.freedesktop.Sdk/aarch64/20.08 org.freedesktop.Platform/aarch64/20.08; then
  echo "Unable to install flatpak dependencies for building.."
  exit 1
fi

echo
echo '**********************************************************************************'
echo '* This utility needs your consent to install the following packages for building *'
echo '**********************************************************************************'

for dep in $DEPS_REQUIRED; do
  echo "$dep"
done

echo "---"

read -p "May I use 'sudo apt-get install -y' to check for and install these dependencies? [N/y] " -n 1 -r
if ! [[ $REPLY =~ ^[Yy]$ ]]
then
  echo "$REPLY"
  echo "Ok. Exiting here."
  exit 1
else
  echo
  echo "Thanks! The build process should no longer need assistance."
  echo "Feel free to step away for a break (continuing after 5 seconds) ..."
  sleep 5
fi

if ! sudo apt-get install -y ${DEPS_REQUIRED}; then
  echo "Unable to run 'apt-get install' to install dependencies. Were there any errors displayed above?"
  exit 1
fi

echo
echo "Dependencies installed. Proceeding with installation .."
echo

git clone https://github.com/flathub/com.prusa3d.PrusaSlicer --recurse-submodules
cd com.prusa3d.PrusaSlicer

# Replace the targeted commit with our desired value
jq --arg c "${LATEST_VERSION}" --arg u "${PS_REPO}" '(.modules[] | objects | .sources[] | select(.type == "archive")) |= {"type":"git", "url": $u, "commit": $c}' com.prusa3d.PrusaSlicer.json > com.prusa3d.PrusaSlicer.json.tmp
cat com.prusa3d.PrusaSlicer.json.tmp
mv com.prusa3d.PrusaSlicer.json.tmp com.prusa3d.PrusaSlicer.json

time flatpak-builder --default-branch=development --repo=repo --force-clean build-dir com.prusa3d.PrusaSlicer.json
echo "Finished build process. Exporting to 'repo'"
echo "Here's some information to help with generating and posting a release on GitHub:"
time flatpak build-bundle ./repo "PrusaSlicer-${LATEST_VERSION##version_}-GTK3-${DPKG_ARCH}.flatpak" com.prusa3d.PrusaSlicer development

cat <<EOF
  Tag: ${LATEST_VERSION}
  -----
  This flatpak mirrors PrusaSlicer's [upstream ${LATEST_VERSION}](https://github.com/prusa3d/PrusaSlicer/releases/tag/${LATEST_VERSION}).
  -----
EOF

