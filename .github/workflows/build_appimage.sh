#!/bin/bash -e

# This script is for building AppImage
# Please run this script in docker image: ubuntu:20.04
# E.g: docker run --rm -v `git rev-parse --show-toplevel`:/build ubuntu:20.04 /build/.github/workflows/build_appimage.sh
# If you need keep store build cache in docker volume, just like:
#   $ docker volume create qbee-cache
#   $ docker run --rm -v `git rev-parse --show-toplevel`:/build -v qbee-cache:/var/cache/apt -v qbee-cache:/usr/src ubuntu:20.04 /build/.github/workflows/build_appimage.sh
# Artifacts will copy to the same directory.

set -o pipefail

# match qt version prefix. E.g 5 --> 5.15.2, 5.12 --> 5.12.10
export QT_VER_PREFIX="6"
export LIBTORRENT_BRANCH="RC_2_0"
export LC_ALL="C.UTF-8"
export DEBIAN_FRONTEND=noninteractive
export PKG_CONFIG_PATH=/usr/local/lib64/pkgconfig
export SELF_DIR="$(dirname "$(readlink -f "${0}")")"

. ${SELF_DIR}/utils.sh
. ${SELF_DIR}/prepare_source.sh
. ${SELF_DIR}/prepare_boost.sh
. ${SELF_DIR}/prepare_ssl.sh
. ${SELF_DIR}/prepare_cmake.sh
. ${SELF_DIR}/prepare_ninja.sh
. ${SELF_DIR}/prepare_qt.sh
. ${SELF_DIR}/prepare_libtorrent.sh
. ${SELF_DIR}/build_qbittorrent.sh



prepare_source

prepare_baseenv() {
  retry apt update
  retry apt install -y software-properties-common apt-transport-https
  # retry apt-add-repository -yn ppa:savoury1/backports
  retry apt-add-repository -yn ppa:savoury1/gcc-11

  if [ "${USE_CHINA_MIRROR}" = "1" ]; then
    sed -i 's@http://ppa.launchpad.net@https://launchpad.proxy.ustclug.org@' /etc/apt/sources.list.d/*.list
  fi

  retry apt install -y \
    build-essential \
    curl \
    desktop-file-utils \
    g++-11 \
    git \
    libbrotli-dev \
    libfontconfig1-dev \
    libfreetype6-dev \
    libgl1-mesa-dev \
    libgtk-3-dev \
    libicu-dev \
    libssl-dev \
    libwayland-dev \
    libwayland-egl-backend-dev \
    libx11-dev \
    libx11-xcb-dev \
    libxcb1-dev \
    libxcb1-dev \
    libxcb-cursor-dev \
    libxcb-glx0-dev \
    libxcb-icccm4-dev \
    libxcb-image0-dev \
    libxcb-keysyms1-dev \
    libxcb-randr0-dev \
    libxcb-render-util0-dev \
    libxcb-shape0-dev \
    libxcb-shm0-dev \
    libxcb-sync-dev \
    libxcb-util-dev \
    libxcb-xfixes0-dev \
    libxcb-xinerama0-dev \
    libxcb-xkb-dev \
    libxext-dev \
    libxfixes-dev \
    libxi-dev \
    libxkbcommon-dev \
    libxkbcommon-x11-dev \
    libxrender-dev \
    libzstd-dev \
    pkg-config \
    unzip \
    zlib1g-dev \
    zsync

  update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-11 100
  update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-11 100

  apt autoremove --purge -y
  # strip all compiled files by default
  export CFLAGS='-s'
  export CXXFLAGS='-s'
  # Force refresh ld.so.cache
  ldconfig
}

build_appimage() {
  # build AppImage
  linuxdeploy_qt_download_url="https://github.com/probonopd/linuxdeployqt/releases/download/continuous/linuxdeployqt-continuous-x86_64.AppImage"
  if [ x"${USE_CHINA_MIRROR}" = x1 ]; then
    linuxdeploy_qt_download_url="https://ghp.ci/${linuxdeploy_qt_download_url}"
  fi
  [ -x "/tmp/linuxdeployqt-continuous-x86_64.AppImage" ] || retry curl -kSLC- -o /tmp/linuxdeployqt-continuous-x86_64.AppImage "${linuxdeploy_qt_download_url}"
  chmod -v +x '/tmp/linuxdeployqt-continuous-x86_64.AppImage'
  cd "/tmp/qbee"
  ln -svf usr/share/icons/hicolor/scalable/apps/qbittorrent.svg /tmp/qbee/AppDir/
  ln -svf qbittorrent.svg /tmp/qbee/AppDir/.DirIcon
  cat >/tmp/qbee/AppDir/AppRun <<EOF
#!/bin/bash -e

this_dir="\$(readlink -f "\$(dirname "\$0")")"
export XDG_DATA_DIRS="\${this_dir}/usr/share:\${XDG_DATA_DIRS}:/usr/share:/usr/local/share"
export QT_QPA_PLATFORMTHEME=gtk3
unset QT_STYLE_OVERRIDE

# Force set openssl config directory to an invalid directory to fallback to use default openssl config.
# This can avoid some distributions (mainly Fedora) having some strange patches or configurations
# for openssl that make the libssl in Appimage bundle unavailable.
export OPENSSL_CONF="\${this_dir}"

# Find the system certificates location
# https://gitlab.com/probono/platformissues/blob/master/README.md#certificates
possible_locations=(
  "/etc/ssl/certs/ca-certificates.crt"                # Debian/Ubuntu/Gentoo etc.
  "/etc/pki/tls/certs/ca-bundle.crt"                  # Fedora/RHEL
  "/etc/ssl/ca-bundle.pem"                            # OpenSUSE
  "/etc/pki/tls/cacert.pem"                           # OpenELEC
  "/etc/ssl/certs"                                    # SLES10/SLES11, https://golang.org/issue/12139
  "/usr/share/ca-certs/.prebuilt-store/"              # Clear Linux OS; https://github.com/knapsu/plex-media-player-appimage/issues/17#issuecomment-437710032
  "/system/etc/security/cacerts"                      # Android
  "/etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem" # CentOS/RHEL 7
  "/etc/ssl/cert.pem"                                 # Alpine Linux
)

for location in "\${possible_locations[@]}"; do
  if [ -r "\${location}" ]; then
    export SSL_CERT_FILE="\${location}"
    break
  fi
done

exec "\${this_dir}/usr/bin/qbittorrent" "\$@"
EOF
  chmod 755 -v /tmp/qbee/AppDir/AppRun

  extra_plugins=(
    iconengines
    imageformats
    platforminputcontexts
    platforms
    platformthemes
    sqldrivers
    styles
    tls
    wayland-decoration-client
    wayland-graphics-integration-client
    wayland-shell-integration
  )
  exclude_libs=(
    libatk-1.0.so.0
    libatk-bridge-2.0.so.0
    libatspi.so.0
    libblkid.so.1
    libboost_filesystem.so.1.58.0
    libboost_system.so.1.58.0
    libboost_system.so.1.65.1
    libbsd.so.0
    libcairo-gobject.so.2
    libcairo.so.2
    libcapnp-0.5.3.so
    libcapnp-0.6.1.so
    libdatrie.so.1
    libdbus-1.so.3
    libepoxy.so.0
    libffi.so.6
    libgcrypt.so.20
    libgdk-3.so.0
    libgdk_pixbuf-2.0.so.0
    libgdk-x11-2.0.so.0
    libgio-2.0.so.0
    libglib-2.0.so.0
    libgmodule-2.0.so.0
    libgobject-2.0.so.0
    libgraphite2.so.3
    libgtk-3.so.0
    libgtk-x11-2.0.so.0
    libkj-0.5.3.so
    libkj-0.6.1.so
    liblz4.so.1
    liblzma.so.5
    libmirclient.so.9
    libmircommon.so.7
    libmircore.so.1
    libmirprotobuf.so.3
    libmount.so.1
    libpango-1.0.so.0
    libpangocairo-1.0.so.0
    libpangoft2-1.0.so.0
    libpcre2-8.so.0
    libpcre.so.3
    libpixman-1.so.0
    libprotobuf-lite.so.9
    libselinux.so.1
    libsystemd.so.0
    libthai.so.0
    libwayland-client.so.0
    libwayland-cursor.so.0
    libwayland-egl.so.1
    libwayland-server.so.0
    libX11-xcb.so.1
    libXau.so.6
    libxcb-cursor.so.0
    libxcb-glx.so.0
    libxcb-icccm.so.4
    libxcb-image.so.0
    libxcb-keysyms.so.1
    libxcb-randr.so.0
    libxcb-render.so.0
    libxcb-render-util.so.0
    libxcb-shape.so.0
    libxcb-shm.so.0
    libxcb-sync.so.1
    libxcb-util.so.1
    libxcb-xfixes.so.0
    libxcb-xkb.so.1
    libXcomposite.so.1
    libXcursor.so.1
    libXdamage.so.1
    libXdmcp.so.6
    libXext.so.6
    libXfixes.so.3
    libXinerama.so.1
    libXi.so.6
    libxkbcommon.so.0
    libxkbcommon-x11.so.0
    libXrandr.so.2
    libXrender.so.1
  )

  # fix AppImage output file name, maybe not needed anymore since appimagetool lets you set output file name?
  sed -i 's/Name=qBittorrent.*/Name=qBittorrent-Enhanced-Edition/;/SingleMainWindow/d' /tmp/qbee/AppDir/usr/share/applications/*.desktop

  export APPIMAGE_EXTRACT_AND_RUN=1
  /tmp/linuxdeployqt-continuous-x86_64.AppImage \
    /tmp/qbee/AppDir/usr/share/applications/*.desktop \
    -always-overwrite \
    -bundle-non-qt-libs \
    -no-copy-copyright-files \
    -extra-plugins="$(join_by ',' "${extra_plugins[@]}")" \
    -exclude-libs="$(join_by ',' "${exclude_libs[@]}")"

  # Workaround to use the static runtime with the appimage
  ARCH="$(arch)"
  appimagetool_download_url="https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-${ARCH}.AppImage"
  if [ x"${USE_CHINA_MIRROR}" = x1 ]; then
    appimagetool_download_url="https://ghp.ci/${appimagetool_download_url}"
  fi
  [ -x "/tmp/appimagetool-${ARCH}.AppImage" ] || retry curl -kSLC- -o /tmp/appimagetool-"${ARCH}".AppImage "${appimagetool_download_url}"
  chmod -v +x "/tmp/appimagetool-${ARCH}.AppImage"
  /tmp/appimagetool-"${ARCH}".AppImage --comp zstd --mksquashfs-opt -Xcompression-level --mksquashfs-opt 20 \
    -u "zsync|https://github.com/${GITHUB_REPOSITORY}/releases/latest/download/qBittorrent-Enhanced-Edition-${ARCH}.AppImage.zsync" \
    /tmp/qbee/AppDir /tmp/qbee/qBittorrent-Enhanced-Edition-"${ARCH}".AppImage
}

move_artifacts() {
  # output file name should be qBittorrent-Enhanced-Edition-x86_64.AppImage
  cp -fv /tmp/qbee/qBittorrent-Enhanced-Edition*.AppImage* "${SELF_DIR}/"
}

prepare_baseenv
prepare_buildenv
# compile openssl 3.x. qBittorrent >= 5.0 required openssl 3.x
prepare_ssl
prepare_qt
preapare_libboost
prepare_libtorrent
build_qbittorrent
build_appimage
move_artifacts
