# frozen_string_literal: true

require_relative 'lib/warren/version'

Gem::Specification.new do |spec|
  spec.name          = 'sanger_warren'
  spec.version       = Warren::VERSION
  spec.authors       = ['James Glover']
  spec.email         = ['james.glover@sanger.ac.uk']

  spec.summary       = 'Configuring and managing bunny RabbitMQ connections'
  spec.description   = <<~DESCRIPTION
    Warren provides connection pooling for RabbitMQ connections. It also adds
    the ability to switch in different adapters during testing and development.
  DESCRIPTION
  spec.homepage = 'https://github.com/sanger/warren'
  spec.required_ruby_version = Gem::Requirement.new('>= 2.6.0')
  spec.license = 'GPL'

  # spec.metadata["allowed_push_host"] = "TODO: Set to 'http://mygemserver.com'"

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/sanger/warren'
  spec.metadata['changelog_uri'] = 'https://github.com/sanger/warren/blob/master/CHANGELOG.md'
  spec.metadata['documentation_uri'] = 'https://rubydoc.info/gems/sanger_warren'

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir = 'bin'
  spec.executables << 'warren'
  spec.require_paths = ['lib']

  # Dependencies
  spec.add_runtime_dependency 'bunny', '~> 2.17.0'
  spec.add_runtime_dependency 'connection_pool', '~> 2.2.0'
  spec.add_runtime_dependency 'multi_json', '~> 1.0'
  spec.add_runtime_dependency 'thor', '~> 1.1.0'
end
