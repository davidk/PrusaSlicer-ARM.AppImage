#!/bin/bash
# stage-release.sh
# A utility for staging a release and uploading assets
# Limitation: Can only be used with the containerized build system
#
# Setup:
# * Configure a github token with the appropriate permissions to your repository.
# * Name it GITHUB_TOKEN and place it in ~/.config/github-token.
# * Change the variables below, like REPO_URL and target_commitish
#
# Running:
# * Allow container-build.sh to finish.
# * Run this utilitiy with ./stage-release.sh ../aarch64-build.log

source ~/.config/github-token

# Live production repo, change for testing if desired
REPO_URL="davidk/PrusaSlicer-ARM.AppImage"

if [[ $# -eq 0 ]]; then
  echo "usage: $0 [{arch64,armhf}-build.log] .."
  exit
fi

if [[ ! -e "$1" ]]; then
  echo "error: could not find log file at $1 to process .."
  exit 1
fi

VERSION="$(grep -E '.+\> version_.+[0-9]$' "$1" | tail -n1 | awk '{print $NF}')"

if [[ -z "${VERSION}" ]]; then
  echo "error: could not find version from log file at $1 to process. (hint: naming scheme in build log has changed and might be weirdly written out by build.sh?) .."
  exit 1
fi

LOG="$(sed -e 's/aarch64> //' < "$1" | sed -e 's/armhf> //' | sed -e "1,/PrusaSlicer-${VERSION#version_} ARM AppImages/ d" | grep -vE '^(real|user|sys)' | jq -csR)"

shift 1

if [[ -z "${LOG}" ]]; then
  echo "error: log could not be parsed. did the build complete cleanly(?) and is this the right .log file? (hint: this is probably aarch64-build.log)"
  exit 1
fi

RELEASE=$(curl -qsSL \
  -X POST \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer ${GITHUB_TOKEN}"\
  -H "X-GitHub-Api-Version: 2022-11-28" \
  https://api.github.com/repos/${REPO_URL}/releases \
  --data-binary @- << EOF
{"tag_name":"${VERSION}",
"target_commitish":"main",
"name":"PrusaSlicer-${VERSION#version_} ARM AppImages",
"body":${LOG},
"draft":true,
"prerelease":false,
"generate_release_notes":false}
EOF
)

echo "--- Release information from GitHub ---"
echo "${RELEASE}"
echo "--- Release information from GitHub ---"

RELEASE_ID=$(echo "${RELEASE}" | jq .id)

if [[ -z ${RELEASE_ID} ]] || [[ "${RELEASE_ID}" == "null" ]]; then
  echo "error: no release id found. this probably means that the release could not be created for some reason (hint: check output above).."
  exit 1
fi

echo "Generating SHA256SUMS for AppImages .."
{ opwd="$PWD"; cd ../PrusaSlicerBuild-aarch64/ || exit; sha256sum *.AppImage; cd ../PrusaSlicerBuild-armhf/ || exit; sha256sum *.AppImage || exit; cd "$opwd" || exit; } > SHA256SUMS

echo "Uploading AppImages and files to release ID ${RELEASE_ID}"


for fn in ../PrusaSlicerBuild-aarch64/*.AppImage ../PrusaSlicerBuild-armhf/*.AppImage SHA256SUMS; do
  echo
  echo
  echo ">>> Uploading ${fn} <<<"
  echo

  curl -L \
  -X POST \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer ${GITHUB_TOKEN}"\
  -H "X-GitHub-Api-Version: 2022-11-28" \
  -H "Content-Type: application/octet-stream" \
  "https://uploads.github.com/repos/${REPO_URL}/releases/${RELEASE_ID}/assets?name=$(basename "${fn}")" \
  --data-binary "@${fn}"

done

echo
echo "Complete .."
