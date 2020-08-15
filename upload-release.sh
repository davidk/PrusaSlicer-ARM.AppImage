#!/bin/bash
# upload-release.sh
# This pushes a release file to GitHub. It requires a premade release where assets can be added
# 
# ~/.config/.githubconfig:
# token="[github personal access token: https://github.com/settings/tokens]"
# release_id="[id of a release to upload to, found here: https://api.github.com/repos/yours/PrusaSlicer-ARM.AppImage/releases]"
# repo="yours/PrusaSlicer-ARM.AppImage"
source ~/.config/.githubconfig

FILE="$1"

[[ -z "$FILE" ]] && echo "usage: $0 [file to upload]" && exit 1;

RELEASE_URL="https://uploads.github.com/repos/${repo}/releases/${release_id}/assets?name=$(basename $FILE)"

echo "Uploading ${FILE} to Github release ${release_id}"

cat ${FILE} | curl -H "Authorization: token ${token}" \
     -H "Content-Type: $(file -b --mime-type $FILE)" \
     --data-binary @- ${RELEASE_URL}
