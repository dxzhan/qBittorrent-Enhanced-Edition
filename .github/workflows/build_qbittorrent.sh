#!/bin/bash -e

build_qbittorrent() {
  echo "build qbittorrent"
  cd "${SELF_DIR}/../../"
  rm -fr build/CMakeCache.txt
  if [ -n "${CROSS_HOST}" ]; then
    cmake \
        -B build \
        -G "Ninja" \
        -DGUI=off \
        -DQT_HOST_PATH="/usr/src/qt-host/${qt_ver}/gcc_64/" \
        -DSTACKTRACE=off \
        -DBUILD_SHARED_LIBS=off \
        -DCMAKE_INSTALL_PREFIX="${CROSS_PREFIX}" \
        -DCMAKE_PREFIX_PATH="${QT_BASE_DIR}/lib/cmake/" \
        -DCMAKE_BUILD_TYPE="Release" \
        -DCMAKE_CXX_STANDARD="17" \
        -DCMAKE_SYSTEM_NAME="${TARGET_HOST}" \
        -DCMAKE_SYSTEM_PROCESSOR="${TARGET_ARCH}" \
        -DCMAKE_SYSROOT="${CROSS_PREFIX}" \
        -DCMAKE_CXX_COMPILER="${CROSS_HOST}-g++" \
        -DCMAKE_EXE_LINKER_FLAGS="-static"

    cmake --build build
    cmake --install build

    if [ "${TARGET_HOST}" = "Windows" ]; then
        cp -fv "src/release/qbittorrent-nox.exe" /tmp/
    else
        cp -fv "${CROSS_PREFIX}/bin/qbittorrent-nox" /tmp/
    fi
  else
    cmake \
        -B build \
        -G "Ninja" \
        -DCMAKE_PREFIX_PATH="${QT_BASE_DIR}/lib/cmake/" \
        -DCMAKE_BUILD_TYPE="Release" \
        -DCMAKE_CXX_STANDARD="17" \
        -DCMAKE_INSTALL_PREFIX="/tmp/qbee/AppDir/usr"
    cmake --build build
    rm -fr /tmp/qbee/
    cmake --install build
  fi
}
