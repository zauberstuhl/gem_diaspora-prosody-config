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

require "fileutils"

class Prosody
  GEMDIR = Gem::Specification.find_by_name("prosody2gem").gem_dir

  def self.config(opts = {})
    cfg = "#{GEMDIR}/prosody/etc/prosody/prosody.cfg.lua"

    if opts[:file] && opts[:file] =~ /^\//
      unless FileUtils.ln_s(opts[:file], cfg, {:force => true})
        abort("Something went wrong while creating the symlink!")
      end
    else
      abort("Cannot set new configuration file. It has to be absolute!")
    end
  end

  def self.start
    system("cd #{GEMDIR}/prosody && bin/prosody")
  end
end
