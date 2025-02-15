#!/bin/bash

prepare_libtorrent() {
  echo "libtorrent-rasterbar branch: ${LIBTORRENT_BRANCH}"
  libtorrent_git_url="https://github.com/arvidn/libtorrent.git"
  if [ "${USE_CHINA_MIRROR}" = "1" ]; then
    libtorrent_git_url="https://ghp.ci/${libtorrent_git_url}"
  fi
  if [ ! -d "/usr/src/libtorrent-rasterbar-${LIBTORRENT_BRANCH}/" ]; then
    retry git clone --depth 1 --recursive --shallow-submodules --branch "${LIBTORRENT_BRANCH}" \
      "${libtorrent_git_url}" \
      "/usr/src/libtorrent-rasterbar-${LIBTORRENT_BRANCH}/"
  fi
  cd "/usr/src/libtorrent-rasterbar-${LIBTORRENT_BRANCH}/"
  if [ "${USE_CHINA_MIRROR}" != "1" ]; then
    if ! git pull; then
        # if pull failed, retry clone the repository.
        cd /
        rm -fr "/usr/src/libtorrent-rasterbar-${LIBTORRENT_BRANCH}/"
        retry git clone --depth 1 --recursive --shallow-submodules --branch "${LIBTORRENT_BRANCH}" \
        "${libtorrent_git_url}" \
        "/usr/src/libtorrent-rasterbar-${LIBTORRENT_BRANCH}/"
        cd "/usr/src/libtorrent-rasterbar-${LIBTORRENT_BRANCH}/"
    fi
  fi
  rm -fr build/CMakeCache.txt
  if [ -n "${CROSS_HOST}" ]; then
    # TODO: solve mingw build
    if [ "${TARGET_HOST}" = "Windows" ]; then
        find -type f \( -name '*.cpp' -o -name '*.h' -o -name '*.hpp' \) -print0 |
        xargs -0 -r sed -i 's/Windows\.h/windows.h/g;
                            s/Shellapi\.h/shellapi.h/g;
                            s/Shlobj\.h/shlobj.h/g;
                            s/Ntsecapi\.h/ntsecapi.h/g;
                            s/#include\s*<condition_variable>/#include "mingw.condition_variable.h"/g;
                            s/#include\s*<future>/#include "mingw.future.h"/g;
                            s/#include\s*<invoke>/#include "mingw.invoke.h"/g;
                            s/#include\s*<mutex>/#include "mingw.mutex.h"/g;
                            s/#include\s*<shared_mutex>/#include "mingw.shared_mutex.h"/g;
                            s/#include\s*<thread>/#include "mingw.thread.h"/g'
    fi
  fi
  if [ -n "${CROSS_HOST}" ]; then
    cmake \
        -B build \
        -G "Ninja" \
        -DCMAKE_INSTALL_PREFIX="${CROSS_PREFIX}" \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_CXX_STANDARD=17 \
        -Dstatic_runtime=on \
        -DBUILD_SHARED_LIBS=off \
        -DCMAKE_SYSTEM_NAME="${TARGET_HOST}" \
        -DCMAKE_SYSTEM_PROCESSOR="${TARGET_ARCH}" \
        -DCMAKE_SYSROOT="${CROSS_PREFIX}" \
        -DCMAKE_C_COMPILER="${CROSS_HOST}-gcc" \
        -DCMAKE_CXX_COMPILER="${CROSS_HOST}-g++"
  else
    cmake \
        -B build \
        -G "Ninja" \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_CXX_STANDARD=17
  fi
  cmake --build build
  cmake --install build
  if [ -z "${CROSS_HOST}" ]; then
    # force refresh ld.so.cache
    ldconfig
  fi
  echo "libtorrent done!"
}
