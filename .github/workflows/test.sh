#!/bin/bash -e

. utils.sh

#echo "$(retry curl -ksSL --compressed https://www.boost.org/users/download/ \| grep data-current-boost-version)"

#echo "$(retry curl -ksSL --compressed https://www.boost.org/users/download/ \| grep data-current-boost-version \| sed -r 's/\"//g')"
#echo "$(retry curl -ksSL --compressed https://www.boost.org/users/download/ \| grep data-current-boost-version \| sed -r 's/\"//g' \| sed -r 's/data-current-boost-version=//g')"

boost_ver="$(retry curl -ksSL --compressed https://www.boost.org/users/download/ \| grep data-current-boost-version \| sed -r 's/\\s//g' \| sed -r 's/\"//g' \| sed -r 's/data-current-boost-version=//g')"

#boost_ver1="$(curl -ksSL --compressed https://www.boost.org/users/download/ \| grep data-current-boost-version \| sed -r 's/\"//g' \| sed -r 's/data-current-boost-version=//g' \| sed -r 's/\s//g')"


echo "${boost_ver}"
#echo "${boost_ver1}"
