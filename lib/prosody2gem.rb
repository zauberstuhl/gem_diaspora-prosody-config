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
