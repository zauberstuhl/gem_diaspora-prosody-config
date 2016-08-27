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

require 'fileutils'
require 'digest/md5'

module Prosody
  NAME = 'diaspora-prosody-config'.freeze
  GEMDIR = Gem::Specification.find_by_name(NAME).gem_dir.freeze
  WRAPPERCFG = "#{GEMDIR}/etc/prosody.cfg.lua".freeze
  DIASPORACFG = "#{FileUtils.pwd}/config/prosody.cfg.lua".freeze

  # Catch signal interrupt
  # for a clean shutdown
  Signal.trap("TERM") {
    shutdown
    exit
  }

  def self.start
    if check_sanity.nil?
      @prosody_pid = Process.spawn("#{find_binary} --config #{WRAPPERCFG}")
      # Prosody was forked into background
      # Let's wait till the Wrapper
      # will be killed or prosody itself
      Process.waitpid(@prosody_pid)
    end
  end

  def self.update_configuration(opts = {})
    # update prosody cfg in diaspora config dir
    gemcfg = "#{WRAPPERCFG}.tpl"
    unless File.exist?(DIASPORACFG)
      FileUtils.cp(gemcfg, DIASPORACFG)
    end

    config = File.read(DIASPORACFG)
    config_params(opts).each do |k, v|
      config.gsub!(/\#\{#{k}\}/, "#{v}")
    end
    File.open(WRAPPERCFG, 'w') {|f| f.write(config) }
    # check if prosody is available
    check_sanity
  end

  def self.find_binary
    ENV['PATH'].split(':').each do |p|
      prosodybin = "#{p}/prosody"
      return prosodybin if File.exist?(prosodybin)
    end
    abort <<-eos
FATAL:
*****************************************************************
#{NAME} wasn't able to find your prosody binary.
Have you installed prosody (http://prosody.im/download/start)?

If you run Prosody or any other XMPP server by yourself you can
disable #{NAME} by editing your diaspora.yml:
configuration:
  chat:
    server:
      enabled: false
*****************************************************************
    eos
  end

  def self.check_sanity
    # check if configuration is matching
    usrcfg = Digest::MD5.hexdigest(File.read(DIASPORACFG))
    gemcfg = Digest::MD5.hexdigest(File.read("#{WRAPPERCFG}.tpl"))
    unless usrcfg.eql?(gemcfg)
      abort <<-eos
FATAL:
*****************************************************************

#{usrcfg} != #{gemcfg}

You modified #{DIASPORACFG}
Please run:
  cp config/prosody.cfg.lua $(bundle show diaspora-prosody-config)/etc/prosody.cfg.lua.tpl

Otherwise your configuration changes will not take effect!
*****************************************************************
      eos
    end
    # check on bcrypt and warn
    bcrypt_so = %x(find /usr/local/lib -name bcrypt.so) rescue ''
    if bcrypt_so.empty?
      warn("#{NAME}: bcrypt is required for diaspora authentication")
    end
    # check prosody version
    about = %x(#{find_binary}ctl --config #{WRAPPERCFG} about)
    version_string = begin
      about.match(/prosody\s(\d+\.\d+\.\d+)/i).captures[0]
    rescue
      abort "#{NAME}: #{about}"
    end
    version = Gem::Version.new(version_string)
    if version < Gem::Version.new('0.9.0')
      abort "#{NAME}: Your're prosody version should be >= 0.9.0"
    end
  end

  def self.config_params(opts)
    db = Rails.application.config.database_configuration[Rails.env]
    hostname = AppConfig.environment.url
      .gsub(/^http(s){0,1}:\/\/|\/$/, '')
      .to_s rescue 'localhost'

    opts[:virtualhost_ssl_key] = "#{opts[:certs]}/#{hostname}.key"
    opts[:virtualhost_ssl_crt] = "#{opts[:certs]}/#{hostname}.crt"

    opts[:plugin_path] = "#{GEMDIR}/modules"
    opts[:virtualhost_hostname] =
      hostname.gsub(/^http(s){0,1}:\/\/|\/$/, '').to_s rescue 'localhost'

    opts[:virtualhost_driver] =
      case opts[:virtualhost_driver]
      when 'mysql2' then 'MySQL'
      when 'postgresql' then 'PostgreSQL'
      else 'SQLite3'
      end
    opts
  end

  def self.shutdown
    unless @prosody_pid.nil?
      Process.kill(9, @prosody_pid)
    end
  end

  private_class_method :find_binary, :check_sanity, :config_params, :shutdown
end
