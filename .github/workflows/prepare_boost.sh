#!/bin/bash

prepare_boost() {
  if [ -z "${boost_ver}" ]; then
    boost_ver="$(retry curl -ksSL --compressed https://www.boost.org/users/download/ \| grep data-current-boost-version \| sed 's/\"//g' \| sed 's/data-current-boost-version=//g' \| sed 's/\\s//g')"
  fi
  if [ -z "${boost_ver}" ]; then
    boost_ver="1.87.0"
  fi
  echo "Boost version ${boost_ver}"
  mkdir -p "/usr/src/boost-${boost_ver}/"
  apt install -y bison
  if [ ! -f "/usr/src/boost-${boost_ver}/.unpack_ok" ]; then
    boost_latest_url="https://sourceforge.net/projects/boost/files/boost/${boost_ver}/boost_${boost_ver//./_}.tar.gz/download"
    retry curl -kL "${boost_latest_url}" \| tar -zxf - -C "/usr/src/boost-${boost_ver}/" --strip-components 1
    touch "/usr/src/boost-${boost_ver}/.unpack_ok"
  fi
  cd "/usr/src/boost-${boost_ver}/"
  if [ -n "${CROSS_HOST}" ]; then
    echo "using gcc : cross : ${CROSS_HOST}-g++ ;" >~/user-config.jam
  fi
  if [ ! -f ./b2 ]; then
    ./bootstrap.sh
  fi
  if [ -n "${CROSS_HOST}" ]; then
    ./b2 -d0 -q install --prefix="${CROSS_PREFIX}" --with-system toolset=gcc-cross variant=release link=static runtime-link=static
  else
    ./b2 -d0 -q install --with-system variant=release link=shared runtime-link=shared
  fi
  cd "/usr/src/boost-${boost_ver}/tools/build"
  if [ ! -f ./b2 ]; then
    ./bootstrap.sh
  fi
  if [ -n "${CROSS_HOST}" ]; then
    ./b2 -d0 -q install --prefix="${CROSS_ROOT}"
  else
    ./b2 -d0 -q install variant=release link=shared runtime-link=shared
  fi
  echo "Boost version ${boost_ver} done!"
}
