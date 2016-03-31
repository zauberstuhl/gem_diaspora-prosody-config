#! /bin/bash
#
# RubyGem Wrapper for the Prosody XMPP Server
# Copyright (C) 2016  Lukas Matt <lukas@zauberstuhl.de>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

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

tar -xzf $TGZ && cd ${TGZ%.*.*} && ./configure \
  --prefix=$(pwd |sed 's@/ext\/.*$@@')/prosody \
  --runwith=$(which lua5.1) \
  --with-lua-include=/usr/include/lua5.1

make && make install
