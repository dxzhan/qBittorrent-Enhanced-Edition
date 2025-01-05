#!/bin/bash

prepare_source() {
rm -f /etc/apt/sources.list.d/*.list*
# Ubuntu mirror for local building
if [ "${USE_CHINA_MIRROR}" = "1" ]; then
  source /etc/os-release
  if [ -f /etc/apt/sources.list.d/ubuntu.sources ]; then
    cat >/etc/apt/sources.list.d/ubuntu.sources <<EOF
Types: deb
URIs: http://repo.huaweicloud.com/ubuntu/
Suites: ${UBUNTU_CODENAME} ${UBUNTU_CODENAME}-updates ${UBUNTU_CODENAME}-backports ${UBUNTU_CODENAME}-security
Components: main universe restricted multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg
EOF
  else
    cat >/etc/apt/sources.list <<EOF
deb http://repo.huaweicloud.com/ubuntu/ ${UBUNTU_CODENAME} main restricted universe multiverse
deb http://repo.huaweicloud.com/ubuntu/ ${UBUNTU_CODENAME}-updates main restricted universe multiverse
deb http://repo.huaweicloud.com/ubuntu/ ${UBUNTU_CODENAME}-backports main restricted universe multiverse
deb http://repo.huaweicloud.com/ubuntu/ ${UBUNTU_CODENAME}-security main restricted universe multiverse
EOF
  fi
  export PIP_INDEX_URL="https://repo.huaweicloud.com/repository/pypi/simple"
fi

# keep debs in container for store cache in docker volume
rm -f /etc/apt/apt.conf.d/*
echo 'Binary::apt::APT::Keep-Downloaded-Packages "true";' >/etc/apt/apt.conf.d/01keep-debs
echo -e 'Acquire::https::Verify-Peer "false";\nAcquire::https::Verify-Host "false";' >/etc/apt/apt.conf.d/99-trust-https

# Since cmake 3.23.0 CMAKE_INSTALL_LIBDIR will force set to lib/<multiarch-tuple> on Debian
echo '/usr/local/lib/x86_64-linux-gnu' >/etc/ld.so.conf.d/x86_64-linux-gnu-local.conf
echo '/usr/local/lib64' >/etc/ld.so.conf.d/lib64-local.conf
}
