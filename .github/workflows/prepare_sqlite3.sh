#!/bin/bash

prepare_sqlite3() {
    if [ ! -f "/usr/src/sqlite-autoconf-3500200.tar.gz.download_ok" ]; then
        sqlite3_binary_url="https://sqlite.org/2025/sqlite-autoconf-3500200.tar.gz"
        retry curl -ksSLo "/usr/src/sqlite-autoconf-3500200.tar.gz" "${sqlite3_binary_url}"
        touch "/usr/src/sqlite-autoconf-3500200.tar.gz.download_ok"
    fi
    tar -zxf "/usr/src/sqlite-autoconf-3500200.tar.gz" -C "/usr/src"
    cd /usr/src/sqlite-autoconf-3500200
    ./configure
    make -j$(nproc)
    make install

    echo "sqlite3-3.50.1 done!"
}
