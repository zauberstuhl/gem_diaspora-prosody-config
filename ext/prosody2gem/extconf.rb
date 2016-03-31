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
