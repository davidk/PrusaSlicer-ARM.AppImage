#!/bin/bash

git clone https://github.com/AppImage/pkg2appimage && cp ps.yml pkg2appimage && cd pkg2appimage && ./pkg2appimage ps.yml
