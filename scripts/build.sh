#! /bin/bash

command_exists () {
  type "$1" &> /dev/null;
}

TGZ=prosody-0.9.9.tar.gz
ENDPOINT=https://prosody.im/downloads/source/
if command_exists curl; then
  curl $ENDPOINT$TGZ -o $TGZ
elif command_exists wget; then
  wget $ENDPOINT$TGZ -o $TGZ
else
  echo "Curl nor wget is installed! Aborting.."
  exit 1
fi

tar -xzf $TGZ
cd ${TGZ%.*.*} && ./configure \
  --prefix=$(pwd |sed 's@/[^/]*$@@')/prosody \
  --runwith=$(which lua5.1) \
  --with-lua-include=/usr/include/lua5.1

make && make install
