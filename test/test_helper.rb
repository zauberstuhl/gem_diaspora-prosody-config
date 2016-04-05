require 'diaspora-prosody-config'
require 'minitest/autorun'
require 'fileutils'

# AppConfig.environment.url
module AppConfig
  module Url
    def self.url; 'localhost'; end
  end
  def self.environment; Url; end
end

# Rails.application.config.database_configuration[Rails.env]
module Rails
  module Config
    module Db
      def self.database_configuration
        {
          'development' => {
          'adapter' => 'sqlite3',
          'database' => 'test.db'
        }}
      end
    end
    def self.config; Db; end
  end
  def self.env; 'development'; end
  def self.application; Config; end
end
