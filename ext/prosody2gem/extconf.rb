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

require "mkmf"

# requirements
# lua5.1 liblua5.1-dev libidn11-dev libssl-dev
# and lua-bcrypt (diaspora)

abort "missing lua5.1" unless have_library "lua5.1"
abort "missing libidn" unless have_library "idn"
abort "missing libssl" unless have_library "ssl"

abort "missing lua5.1 header" unless find_header "lua5.1/lua.h"
abort "missing libidn header" unless find_header "idna.h"
abort "missing libssl header" unless find_header "openssl/x509.h"

pwd = (File.expand_path File.dirname(__FILE__)).gsub(/\/ext.*$/, '')
system "#{pwd}/scripts/build.sh"
# TODO move configure-step in build.sh to create_makefile
create_makefile('/dev/null')
