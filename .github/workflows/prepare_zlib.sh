#!/bin/bash

prepare_zlib() {
  if [ "${USE_ZLIB_NG}" = "1" ]; then
    zlib_ng_latest_tag="$(retry curl -ksSL --compressed https://api.github.com/repos/zlib-ng/zlib-ng/releases \| jq -r "'.[0].tag_name'")"
    zlib_ng_latest_url="https://github.com/zlib-ng/zlib-ng/archive/refs/tags/${zlib_ng_latest_tag}.tar.gz"
    echo "zlib-ng version ${zlib_ng_latest_tag}"
    if [ "${USE_CHINA_MIRROR}" = "1" ]; then
      zlib_ng_latest_url="https://ghp.ci/${zlib_ng_latest_url}"
    fi
    if [ ! -f "/usr/src/zlib-ng-${zlib_ng_latest_tag}/.unpack_ok" ]; then
      mkdir -p "/usr/src/zlib-ng-${zlib_ng_latest_tag}/"
      retry curl -ksSL "${zlib_ng_latest_url}" \| tar -zxf - --strip-components=1 -C "/usr/src/zlib-ng-${zlib_ng_latest_tag}/"
      touch "/usr/src/zlib-ng-${zlib_ng_latest_tag}/.unpack_ok"
    fi
    cd "/usr/src/zlib-ng-${zlib_ng_latest_tag}/"
    rm -fr build
    cmake -B build \
      -G Ninja \
      -DBUILD_SHARED_LIBS=OFF \
      -DZLIB_COMPAT=ON \
      -DCMAKE_SYSTEM_NAME="${TARGET_HOST}" \
      -DCMAKE_INSTALL_PREFIX="${CROSS_PREFIX}" \
      -DCMAKE_C_COMPILER="${CROSS_HOST}-gcc" \
      -DCMAKE_CXX_COMPILER="${CROSS_HOST}-g++" \
      -DCMAKE_SYSTEM_PROCESSOR="${TARGET_ARCH}" \
      -DWITH_GTEST=OFF
    cmake --build build
    cmake --install build
    # Fix mingw build sharedlibdir lost issue
    sed -i 's@^sharedlibdir=.*@sharedlibdir=${libdir}@' "${CROSS_PREFIX}/lib/pkgconfig/zlib.pc"
    echo "zlib-ng version ${zlib_ng_latest_tag} done!"
  else
    zlib_ver="$(retry curl -ksSL --compressed https://zlib.net/ \| grep -i "'<FONT.*FONT>'" \| sed -r "'s/.*zlib\s*([^<]+).*/\1/'" \| head -1)"
    echo "zlib version ${zlib_ver}"
    if [ ! -f "/usr/src/zlib-${zlib_ver}/.unpack_ok" ]; then
      mkdir -p "/usr/src/zlib-${zlib_ver}"
      zlib_latest_url="https://sourceforge.net/projects/libpng/files/zlib/${zlib_ver}/zlib-${zlib_ver}.tar.xz/download"
      retry curl -kL "${zlib_latest_url}" \| tar -Jxf - --strip-components=1 -C "/usr/src/zlib-${zlib_ver}"
      touch "/usr/src/zlib-${zlib_ver}/.unpack_ok"
    fi
    cd "/usr/src/zlib-${zlib_ver}"

    if [ "${TARGET_HOST}" = "Windows" ]; then
      make -f win32/Makefile.gcc BINARY_PATH="${CROSS_PREFIX}/bin" INCLUDE_PATH="${CROSS_PREFIX}/include" LIBRARY_PATH="${CROSS_PREFIX}/lib" SHARED_MODE=0 PREFIX="${CROSS_HOST}-" -j$(nproc) install
    else
      CHOST="${CROSS_HOST}" ./configure --prefix="${CROSS_PREFIX}" --static
      make -j$(nproc)
      make install
    fi
    echo "zlib version ${zlib_ver} done!"
  fi
}
