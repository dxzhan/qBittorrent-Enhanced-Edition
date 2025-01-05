#!/bin/bash

prepare_ssl() {
  openssl_filename="$(retry curl -ksSL --compressed https://openssl-library.org/source/ \| grep -o "'>openssl-3\(\.[0-9]*\)*tar.gz<'" \| grep -o "'[^>]*.tar.gz'" \| sort -nr \| head -1)"
  openssl_ver="$(echo "${openssl_filename}" | sed -r 's/openssl-(.+)\.tar\.gz/\1/')"
  mkdir -p "/usr/src/openssl-${openssl_ver}/"

  echo "OpenSSL version ${openssl_ver}"
  if [ ! -f "/usr/src/openssl-${openssl_ver}/.unpack_ok" ]; then
    openssl_latest_url="https://github.com/openssl/openssl/archive/refs/tags/${openssl_filename}"
    if [ "${USE_CHINA_MIRROR}" = "1" ]; then
      openssl_latest_url="https://ghp.ci/${openssl_latest_url}"
    fi
    retry curl -kSL "${openssl_latest_url}" \| tar -zxf - --strip-components=1 -C "/usr/src/openssl-${openssl_ver}/"
    touch "/usr/src/openssl-${openssl_ver}/.unpack_ok"
  fi
  cd "/usr/src/openssl-${openssl_ver}/"
  if [ -n "${CROSS_HOST}" ]; then
    ./Configure -static no-tests --openssldir=/etc/ssl --cross-compile-prefix="${CROSS_HOST}-" --prefix="${CROSS_PREFIX}" "${OPENSSL_COMPILER}"
  else
    ./Configure no-tests --openssldir=/etc/ssl
  fi
  make -j$(nproc)
  make install_sw
  if [ -n "${CROSS_HOST}" ]; then
    if [ -f "${CROSS_PREFIX}/lib64/libssl.a" ]; then
        cp -rfv "${CROSS_PREFIX}"/lib64/. "${CROSS_PREFIX}/lib"
    fi
    if [ -f "${CROSS_PREFIX}/lib32/libssl.a" ]; then
        cp -rfv "${CROSS_PREFIX}"/lib32/. "${CROSS_PREFIX}/lib"
    fi
  else
    ldconfig
  fi
  echo "OpenSSL version ${openssl_ver} done!"
}
