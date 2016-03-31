Gem::Specification.new do |s|
  s.name        = 'prosody2gem'
  s.version     = '0.0.1'
  s.summary     = 'A prosody wrapper for Ruby'
  s.description = 'A prosody wrapper for Ruby'
  s.authors     = ['Lukas Matt']
  s.email       = 'lukas@zauberstuhl.de'
  s.require_paths = ['lib', 'scripts']
  s.files = Dir.glob("lib/**/*") + Dir.glob("scripts/**/*")
  s.homepage    =
    'https://github.com/zauberstuhl/gem_prosody'
  s.license     = 'GPL-3.0'
  s.extensions  = %w[ext/prosody2gem/extconf.rb]
end
