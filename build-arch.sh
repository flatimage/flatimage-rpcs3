#!/usr/bin/env bash

######################################################################
# @author      : Ruan E. Formigoni (ruanformigoni@gmail.com)
# @file        : build
# @created     : Friday Nov 24, 2023 19:06:13 -03
#
# @description : 
######################################################################

set -e

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

build_dir="$SCRIPT_DIR/build"

mkdir "$build_dir"; cd "$build_dir"

# Fetch latest release
read -r url_rpcs3 < <(curl -L -H "Accept: application/vnd.github+json" -H "X-GitHub-Api-Version: 2022-11-28" \
  https://api.github.com/repos/RPCS3/rpcs3-binaries-linux/releases/latest 2>/dev/null |
  jq -r '.assets.[0].browser_download_url')
wget "$url_rpcs3"
appimage_rpcs3="$(basename "$url_rpcs3")"

# Make executable
chmod +x "$build_dir/$appimage_rpcs3"

# Extract appimage
"$build_dir/$appimage_rpcs3" --appimage-extract

# Fetch container
if ! [ -f "$build_dir/arch.tar.xz" ]; then
  wget "https://gitlab.com/api/v4/projects/43000137/packages/generic/fim/continuous/arch.tar.xz"
fi

# Extract container
[ ! -f "$build_dir/arch.fim" ] || rm "$build_dir/arch.fim"
tar xf arch.tar.xz

# FIM_COMPRESSION_LEVEL
export FIM_COMPRESSION_LEVEL=6

# Set perms
"$build_dir"/arch.fim fim-perms-set wayland,x11,pulseaudio,gpu,session_bus,input,usb

# Resize
"$build_dir"/arch.fim fim-resize 3G

# Update
"$build_dir"/arch.fim fim-perms-set fakechroot pacman -Syu --noconfirm

# Install dependencies
"$build_dir"/arch.fim fim-root fakechroot pacman -S libsm lib32-libsm fontconfig lib32-fontconfig noto-fonts --noconfirm

# Compress main image
"$build_dir"/arch.fim fim-compress

# Compress rpcs3
"$build_dir"/arch.fim fim-exec mkdwarfs -i "$build_dir"/squashfs-root/usr -o "$build_dir/rpcs3.dwarfs"

# Include rpcs3
"$build_dir"/arch.fim fim-include-path "$build_dir"/rpcs3.dwarfs "/rpcs3.dwarfs"

# Set default command
"$build_dir"/arch.fim fim-cmd /rpcs3/bin/rpcs3

# Rename
mv "arch.fim" rpcs3-arch.fim


# // cmd: !./%
