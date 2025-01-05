#!/bin/bash

prepare_cmake() {
  if ! which cmake &>/dev/null; then
    if [ ! -f "/usr/src/cmake-${cmake_latest_ver}-linux-x86_64.tar.gz.download_ok" ]; then
        if [ -z "${cmake_latest_ver}" ]; then
            cmake_latest_ver="$(retry curl -ksSL --compressed https://cmake.org/download/ \| grep "'Latest Release'" \| sed -r "'s/.*Latest Release\s*\((.+)\).*/\1/'" \| head -1)"
        fi
        cmake_binary_url="https://github.com/Kitware/CMake/releases/download/v${cmake_latest_ver}/cmake-${cmake_latest_ver}-linux-x86_64.tar.gz"
        cmake_sha256_url="https://github.com/Kitware/CMake/releases/download/v${cmake_latest_ver}/cmake-${cmake_latest_ver}-SHA-256.txt"
        if [ x"${USE_CHINA_MIRROR}" = x1 ]; then
            cmake_binary_url="https://ghp.ci/${cmake_binary_url}"
            cmake_sha256_url="https://ghp.ci/${cmake_sha256_url}"
        fi
        if [ -f "/usr/src/cmake-${cmake_latest_ver}-linux-x86_64.tar.gz" ]; then
            cd /usr/src
            if ! retry curl -ksSL --compressed "${cmake_sha256_url}" \| grep "cmake-${cmake_latest_ver}-linux-x86_64.tar.gz" \| sha256sum -c; then
                rm -f "/usr/src/cmake-${cmake_latest_ver}-linux-x86_64.tar.gz"
            fi
        fi
        if [ ! -f "/usr/src/cmake-${cmake_latest_ver}-linux-x86_64.tar.gz" ]; then
            retry curl -kLo "/usr/src/cmake-${cmake_latest_ver}-linux-x86_64.tar.gz" "${cmake_binary_url}"
            if retry curl -ksSL --compressed "${cmake_sha256_url}" \| grep "cmake-${cmake_latest_ver}-linux-x86_64.tar.gz" \| sha256sum -c; then
                touch "/usr/src/cmake-${cmake_latest_ver}-linux-x86_64.tar.gz.download_ok"
            fi
        fi
        tar -zxf "/usr/src/cmake-${cmake_latest_ver}-linux-x86_64.tar.gz" -C /usr/local --strip-components 1
    fi
  fi
  cmake --version
  echo "cmake-${cmake_latest_ver} done!"
}
