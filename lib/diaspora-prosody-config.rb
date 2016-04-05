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

module Prosody
  GEMDIR = Gem::Specification.find_by_name(
    'diaspora-prosody-config'
  ).gem_dir.freeze

  WRAPPERCFG = "#{GEMDIR}/etc/prosody.cfg.lua".freeze
  DIASPORACFG = "#{FileUtils.pwd}/config/prosody.cfg.lua".freeze

  def self.start
    check_sanity.nil? && system("#{find_binary} --config #{WRAPPERCFG}")
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
  end

  def self.find_binary
    ENV['PATH'].split(':').each do |p|
      prosodybin = "#{p}/prosody"
      return prosodybin if File.exist?(prosodybin)
    end
    abort('Prosody executable is missing please update your PATH variable')
  end

  def self.check_sanity
    # check on bcrypt and warn
    bcrypt_so = %x(find /usr/local/lib -name bcrypt.so) rescue ''
    warn('bcrypt is required for diaspora authentication') if bcrypt_so.empty?
    # check prosody version
    about = %x(#{find_binary}ctl about)
    version_string = begin
      about.match(/prosody\s(\d+\.\d+\.\d+)/i).captures[0]
    rescue
      abort('something went wrong with prosdoyctl')
    end
    version = Gem::Version.new(version_string)
    if version < Gem::Version.new('0.9.0')
      abort('your\'re prosody version should be >= 0.9.0')
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

  private_class_method :find_binary, :check_sanity, :config_params
end
