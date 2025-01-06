#!/bin/bash

prepare_qt() {
  mirror_base_url="https://download.qt.io/official_releases/qt"
  if [ "${USE_CHINA_MIRROR}" = "1" ]; then
    mirror_base_url="https://mirrors.aliyun.com/qt/archive/qt"
  fi
  if [ -z "${qt_major_ver}" ]; then
    qt_major_ver="$(retry curl -ksSL --compressed ${mirror_base_url}/ \| sed -nr "'s@.*href=\"([0-9]+(\.[0-9]+)*)/\".*@\1@p'" \| grep \"^${QT_VER_PREFIX}\" \| head -1)"
  fi
  if [ -z "${qt_ver}" ]; then
    qt_ver="$(retry curl -ksSL --compressed ${mirror_base_url}/${qt_major_ver}/ \| sed -nr "'s@.*href=\"([0-9]+(\.[0-9]+)*)/\".*@\1@p'" \| grep \"^${QT_VER_PREFIX}\" \| head -1)"
  fi

  echo "Using qt version: ${qt_ver}"
  mkdir -p "/usr/src/qtbase-${qt_ver}" "/usr/src/qttools-${qt_ver}"
  if [ -z "${CROSS_HOST}" ]; then
    mkdir -p "/usr/src/qtsvg-${qt_ver}" "/usr/src/qtwayland-${qt_ver}"
  fi
  if [ -n "${CROSS_HOST}" ]; then
    if [ ! -f "/usr/src/qt-host/${qt_ver}/gcc_64/bin/qt.conf" ]; then
        pipx install aqtinstall
        if [ "${USE_CHINA_MIRROR}" = "1" ]; then
            retry "${HOME}/.local/bin/aqt" install-qt -b ${mirror_base_url} -O /usr/src/qt-host linux desktop "${qt_ver}" --archives qtbase qttools icu
        else
            retry "${HOME}/.local/bin/aqt" install-qt -O /usr/src/qt-host linux desktop "${qt_ver}" --archives qtbase qttools icu
        fi
    fi
  fi
  if [ ! -f "/usr/src/qtbase-${qt_ver}/.unpack_ok" ]; then
    qtbase_url="${mirror_base_url}/${qt_major_ver}/${qt_ver}/submodules/qtbase-everywhere-src-${qt_ver}.tar.xz"
    retry curl -kSL "${qtbase_url}" \| tar Jxf - -C "/usr/src/qtbase-${qt_ver}" --strip-components 1
    touch "/usr/src/qtbase-${qt_ver}/.unpack_ok"
  fi
  cd "/usr/src/qtbase-${qt_ver}"
  rm -fr CMakeCache.txt CMakeFiles
  if [ -n "${CROSS_HOST}" ]; then
    if [ "${TARGET_HOST}" = "Windows" ]; then
        QT_BASE_EXTRA_CONF='-xplatform win32-g++'
    fi
  fi
  if [ -n "${CROSS_HOST}" ]; then
  ./configure \
    -prefix "${CROSS_PREFIX}/opt/qt/" \
    -qt-host-path "/usr/src/qt-host/${qt_ver}/gcc_64/" \
    -release \
    -static \
    -c++std c++17 \
    -optimize-size \
    -openssl \
    -openssl-linked \
    -no-gui \
    -no-dbus \
    -no-widgets \
    -no-feature-testlib \
    -no-feature-animation \
    -feature-optimize_full \
    -nomake examples \
    -nomake tests \
    ${QT_BASE_EXTRA_CONF} \
    -device-option "CROSS_COMPILE=${CROSS_HOST}-" \
    -- \
    -DCMAKE_SYSTEM_NAME="${TARGET_HOST}" \
    -DCMAKE_SYSTEM_PROCESSOR="${TARGET_ARCH}" \
    -DCMAKE_C_COMPILER="${CROSS_HOST}-gcc" \
    -DCMAKE_SYSROOT="${CROSS_PREFIX}" \
    -DCMAKE_CXX_COMPILER="${CROSS_HOST}-g++"
  else
  ./configure \
    -ltcg \
    -release \
    -optimize-size \
    -openssl-linked \
    -no-icu \
    -no-directfb \
    -no-linuxfb \
    -no-eglfs \
    -no-feature-testlib \
    -no-feature-vnc \
    -feature-optimize_full \
    -nomake examples \
    -nomake tests
  fi
  echo "========================================================"
  echo "Qt configuration:"
  cmake --build . --parallel
  cmake --install .
  if [ -z "${CROSS_HOST}" ]; then
    export QT_BASE_DIR="$(ls -rd /usr/local/Qt-* | head -1)"
    export LD_LIBRARY_PATH="${QT_BASE_DIR}/lib:${LD_LIBRARY_PATH}"
    export PATH="${QT_BASE_DIR}/bin:${PATH}"
    if [ ! -f "/usr/src/qtsvg-${qt_ver}/.unpack_ok" ]; then
        qtsvg_url="https://download.qt.io/official_releases/qt/${qt_major_ver}/${qt_ver}/submodules/qtsvg-everywhere-src-${qt_ver}.tar.xz"
        retry curl -kSL --compressed "${qtsvg_url}" \| tar Jxf - -C "/usr/src/qtsvg-${qt_ver}" --strip-components 1
        touch "/usr/src/qtsvg-${qt_ver}/.unpack_ok"
    fi
    cd "/usr/src/qtsvg-${qt_ver}"
    rm -fr CMakeCache.txt
    "${QT_BASE_DIR}/bin/qt-configure-module" .
    cmake --build . --parallel
    cmake --install .
    if [ ! -f "/usr/src/qttools-${qt_ver}/.unpack_ok" ]; then
        qttools_url="https://download.qt.io/official_releases/qt/${qt_major_ver}/${qt_ver}/submodules/qttools-everywhere-src-${qt_ver}.tar.xz"
        retry curl -kSL --compressed "${qttools_url}" \| tar Jxf - -C "/usr/src/qttools-${qt_ver}" --strip-components 1
        touch "/usr/src/qttools-${qt_ver}/.unpack_ok"
    fi
    cd "/usr/src/qttools-${qt_ver}"
    rm -fr CMakeCache.txt
    "${QT_BASE_DIR}/bin/qt-configure-module" .
    cmake --build . --parallel
    cmake --install .

    # Remove qt-wayland until next release: https://bugreports.qt.io/browse/QTBUG-104318
    # qt-wayland
    if [ ! -f "/usr/src/qtwayland-${qt_ver}/.unpack_ok" ]; then
        qtwayland_url="https://download.qt.io/official_releases/qt/${qt_major_ver}/${qt_ver}/submodules/qtwayland-everywhere-src-${qt_ver}.tar.xz"
        retry curl -kSL --compressed "${qtwayland_url}" \| tar Jxf - -C "/usr/src/qtwayland-${qt_ver}" --strip-components 1
        touch "/usr/src/qtwayland-${qt_ver}/.unpack_ok"
    fi
    cd "/usr/src/qtwayland-${qt_ver}"
    rm -fr CMakeCache.txt
    "${QT_BASE_DIR}/bin/qt-configure-module" .
    cmake --build . --parallel
    cmake --install .
  fi
  echo "qt version: ${qt_ver} done!"
}
