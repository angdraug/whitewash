Gem::Specification.new do |spec|
  spec.name        = 'whitewash'
  spec.version     = '2.0'
  spec.author      = 'Dmitry Borodaenko'
  spec.email       = 'angdraug@debian.org'
  spec.homepage    = 'https://github.com/angdraug/whitewash'
  spec.summary     = 'Whitelist-based HTML filter for Ruby'
  spec.description = <<-EOF
This module allows Ruby programs to clean up any HTML document or
fragment coming from an untrusted source and to remove all dangerous
constructs that could be used for cross-site scripting or request
forgery.
    EOF
  spec.files       = `git ls-files`.split "\n"
  spec.license     = 'GPL3+'
#  spec.add_dependency('nokogiri')
#  spec.add_development_dependency('rspec')
end
