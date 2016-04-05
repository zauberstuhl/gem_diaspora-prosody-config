Gem::Specification.new do |s|
  s.name        = 'diaspora-prosody-config'
  s.version     = '0.0.3'
  s.summary     = 'A prosody config-wrapper for Diaspora'
  s.description = 'A prosody config-wrapper for Diaspora'
  s.license     = 'GPL-3.0'

  s.authors     = ['Lukas Matt']
  s.email       = 'lukas@zauberstuhl.de'
  s.homepage    = 'https://github.com/zauberstuhl/gem_diaspora-prosody-config'

  s.files       = `git ls-files`.split("\n")
  s.require_paths = ["lib"]

  s.add_development_dependency 'pronto'
  s.add_development_dependency 'pronto-rubocop'
  s.add_development_dependency 'sqlite3'
  s.add_development_dependency 'minitest'
  s.add_development_dependency 'rake'
end
