#!/bin/bash -e

# This script is for static cross compiling
# Please run this script in docker image: abcfy2/muslcc-toolchain-ubuntu:${CROSS_HOST}
# E.g: docker run --rm -v `git rev-parse --show-toplevel`:/build abcfy2/muslcc-toolchain-ubuntu:arm-linux-musleabi /build/.github/workflows/cross_build.sh
# If you need keep store build cache in docker volume, just like:
#   $ docker volume create qbee-nox-cache
#   $ docker run --rm -v `git rev-parse --show-toplevel`:/build -v qbee-nox-cache:/var/cache/apt -v qbee-nox-cache:/usr/src abcfy2/muslcc-toolchain-ubuntu:arm-linux-musleabi /build/.github/workflows/cross_build.sh
# Artifacts will copy to the same directory.

set -o pipefail

# match qt version prefix. E.g 5 --> 5.15.2, 5.12 --> 5.12.10
export QT_VER_PREFIX="6"
export LIBTORRENT_BRANCH="RC_2_0"
export DEBIAN_FRONTEND=noninteractive
# use zlib-ng instead of zlib by default
export USE_ZLIB_NG=${USE_ZLIB_NG:-1}
export PKG_CONFIG_PATH="${CROSS_PREFIX}/opt/qt/lib/pkgconfig:${CROSS_PREFIX}/lib/pkgconfig:${CROSS_PREFIX}/share/pkgconfig:${PKG_CONFIG_PATH}"
export TARGET_ARCH="${CROSS_HOST%%-*}"
export TARGET_HOST="${CROSS_HOST#*-}"
export QT_BASE_DIR="${CROSS_PREFIX}/opt/qt"
export LD_LIBRARY_PATH="${QT_BASE_DIR}/lib:${LD_LIBRARY_PATH}"
export PATH="${QT_BASE_DIR}/bin:${PATH}"

# strip all compiled files by default
export CFLAGS='-s'
export CXXFLAGS='-s'

export SELF_DIR="$(dirname "$(readlink -f "${0}")")"
mkdir -p "/usr/src"


. ${SELF_DIR}/utils.sh
. ${SELF_DIR}/prepare_source.sh
. ${SELF_DIR}/prepare_boost.sh
. ${SELF_DIR}/prepare_ssl.sh
. ${SELF_DIR}/prepare_cmake.sh
. ${SELF_DIR}/prepare_ninja.sh
. ${SELF_DIR}/prepare_zlib.sh
. ${SELF_DIR}/prepare_sqlite3.sh
. ${SELF_DIR}/prepare_qt.sh
. ${SELF_DIR}/prepare_libtorrent.sh
. ${SELF_DIR}/build_qbittorrent.sh

prepare_source

apt update
apt install -y \
  software-properties-common \
  apt-transport-https \
  jq \
  curl \
  git \
  make \
  g++ \
  unzip \
  zip \
  pkg-config \
  pipx \
  python3-pip

# OPENSSL_COMPILER value is from openssl source: ./Configure LIST
# QT_DEVICE and QT_DEVICE_OPTIONS value are from https://github.com/qt/qtbase/tree/dev/mkspecs/devices/
case "${CROSS_HOST}" in
arm-linux*)
  export OPENSSL_COMPILER=linux-armv4
  ;;
aarch64-linux*)
  export OPENSSL_COMPILER=linux-aarch64
  ;;
mips-linux* | mipsel-linux*)
  export OPENSSL_COMPILER=linux-mips32
  ;;
mips64-linux* | mips64el-linux*)
  export OPENSSL_COMPILER=linux64-mips64
  ;;
x86_64-linux*)
  export OPENSSL_COMPILER=linux-x86_64
  ;;
x86_64-*-mingw*)
  export OPENSSL_COMPILER=mingw64
  ;;
i686-*-mingw*)
  export OPENSSL_COMPILER=mingw
  ;;
*)
  export OPENSSL_COMPILER=gcc
  ;;
esac

case "${TARGET_HOST}" in
*"mingw"*)
  TARGET_HOST=Windows
  apt install -y wine
  export WINEPREFIX=/tmp/
  RUNNER_CHECKER="wine"
  ;;
*)
  TARGET_HOST=Linux
  apt install -y "qemu-user-static"
  if [ "${TARGET_ARCH}" = "i686" ]; then
    RUNNER_CHECKER="qemu-i386-static"
  else
    RUNNER_CHECKER="qemu-${TARGET_ARCH}-static"
  fi
  ;;
esac

prepare_cmake
prepare_ninja
prepare_zlib
prepare_sqlite3
prepare_ssl
prepare_boost
prepare_qt
prepare_libtorrent
build_qbittorrent

# check
"${RUNNER_CHECKER}" /tmp/qbittorrent-nox* --version 2>/dev/null

# archive qbittorrent
zip -j9v "${SELF_DIR}/qbittorrent-enhanced-nox_${CROSS_HOST}_static.zip" /tmp/qbittorrent-nox*
