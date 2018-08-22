lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'dbx/version'

Gem::Specification.new do |spec|
  spec.name          = 'dbx'
  spec.version       = Dbx::VERSION
  spec.authors       = ['Scott Pierce']
  spec.email         = ['ddrscott@gmail.com']

  spec.summary       = 'Database utilities'
  spec.homepage      = 'https://github.com/ddrscott/dbx'
  spec.license       = 'MIT'

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_development_dependency 'bundler', '~> 1.16'
  spec.add_development_dependency 'rake', '~> 10.0'
  spec.add_development_dependency 'rspec', '~> 3.0'

  spec.add_dependency 'activerecord', '~> 4.0'
  spec.add_dependency 'activesupport', '~> 4.0'
  spec.add_dependency 'thor'
end
