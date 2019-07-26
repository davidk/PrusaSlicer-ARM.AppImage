#!/bin/bash
echo
echo '*********************************************************************************'
echo '* This utility needs permission to install the following things as dependencies *'
echo '*********************************************************************************'
echo
sudo apt install git cmake libboost-dev libboost-regex-dev libboost-filesystem-dev libboost-thread-dev libboost-log-dev libboost-locale-dev libcurl4-openssl-dev libwxgtk3.0-dev build-essential pkg-config libtbb-dev zlib1g-dev
echo 
[[ -d "./pkg2appimage" ]] || git clone https://github.com/AppImage/pkg2appimage && cp ps.yml ./pkg2appimage && cd pkg2appimage && SYSTEM_ARCH="armhf" ./pkg2appimage ps.yml
