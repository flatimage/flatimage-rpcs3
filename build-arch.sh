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

rm -rf "$build_dir"; mkdir "$build_dir"; cd "$build_dir"

# Fetch jq
wget -Ojq https://github.com/jqlang/jq/releases/download/jq-1.7/jq-linux-amd64
chmod +x jq

# Fetch latest release
read -r url_rpcs3 < <(curl -L -H "Accept: application/vnd.github+json" -H "X-GitHub-Api-Version: 2022-11-28" \
  https://api.github.com/repos/RPCS3/rpcs3-binaries-linux/releases/latest 2>/dev/null |
  "$build_dir"/jq -r '.assets.[0].browser_download_url')
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

# Resize
"$build_dir"/arch.fim fim-resize 3G

# Update
"$build_dir"/arch.fim fim-root fakechroot pacman -Syu --noconfirm

# Install dependencies
"$build_dir"/arch.fim fim-root fakechroot pacman -S libsm lib32-libsm fontconfig lib32-fontconfig noto-fonts --noconfirm

# Install video packages
"$build_dir"/arch.fim fim-root fakechroot pacman -S xorg-server mesa lib32-mesa \
  glxinfo pcre xf86-video-amdgpu vulkan-radeon lib32-vulkan-radeon \
  xf86-video-intel vulkan-intel lib32-vulkan-intel vulkan-tools --noconfirm

# Gameimage dependencies
"$build_dir"/arch.fim fim-root fakechroot pacman -S libappindicator-gtk3 \
  lib32-libappindicator-gtk3 --noconfirm

# Compress main image
"$build_dir"/arch.fim fim-compress

# Compress rpcs3
"$build_dir"/arch.fim fim-exec mkdwarfs -i "$build_dir"/squashfs-root/usr -o "$build_dir/rpcs3.dwarfs"

# Include rpcs3
"$build_dir"/arch.fim fim-include-path "$build_dir"/rpcs3.dwarfs "/rpcs3.dwarfs"

# Include runner script
{ tee "$build_dir"/rpcs3.sh | sed -e "s/^/-- /"; } <<-'EOL'
#!/bin/bash

export LD_LIBRARY_PATH="/rpcs3/lib:$LD_LIBRARY_PATH"

/rpcs3/bin/rpcs3 "$@"
EOL
chmod +x "$build_dir"/rpcs3.sh
"$build_dir"/arch.fim fim-root mkdir -p /fim/scripts
"$build_dir"/arch.fim fim-root cp "$build_dir"/rpcs3.sh /fim/scripts/rpcs3.sh

# Set default command
"$build_dir"/arch.fim fim-cmd /fim/scripts/rpcs3.sh

# Set perms
"$build_dir"/arch.fim fim-perms-set wayland,x11,pulseaudio,gpu,session_bus,input,usb

# Set up /usr overlay
"$build_dir"/arch.fim fim-config-set overlay.usr "/usr overlay"
#shellcheck disable=2016
"$build_dir"/arch.fim fim-config-set overlay.usr.host '"$FIM_DIR_BINARY"/."$FIM_FILE_BINARY.config/overlays/usr"'
"$build_dir"/arch.fim fim-config-set overlay.usr.cont '/usr'

# Rename
mv "$build_dir/arch.fim" rpcs3-arch.fim


# // cmd: !./%
