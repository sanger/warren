# frozen_string_literal: true

require_relative 'lib/Warren/version'

Gem::Specification.new do |spec|
  spec.name          = 'Warren'
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

  # spec.metadata["allowed_push_host"] = "TODO: Set to 'http://mygemserver.com'"

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/sanger/warren'
  spec.metadata['changelog_uri'] = 'https://github.com/sanger/warren/blob/master/CHANGELOG.md'

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']
end
