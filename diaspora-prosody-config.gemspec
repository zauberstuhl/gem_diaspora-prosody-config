Gem::Specification.new do |s|
  s.name        = 'diaspora-prosody-config'
  s.version     = '0.0.6'
  s.summary     = 'Diaspora Configuration Wrapper For Prosodoy'
  s.description = 'This gem maps configuration options from Diaspora to Prosody.'
  s.license     = 'GPL-3.0'

  s.authors     = ['Lukas Matt']
  s.email       = 'lukas@zauberstuhl.de'
  s.homepage    = 'https://github.com/zauberstuhl/gem_diaspora-prosody-config'

  s.files       = `git ls-files`.split("\n")
  s.require_paths = ['lib']

  s.add_development_dependency 'pronto', '~> 0.6.0'
  s.add_development_dependency 'pronto-rubocop', '~> 0.6.1'
  s.add_development_dependency 'sqlite3', '~> 1.3'
  s.add_development_dependency 'minitest', '~> 5.8'
  s.add_development_dependency 'rake', '~> 10.5'
end
