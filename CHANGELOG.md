# Changelog

Keeps track of notable changes. Please remember to add new behaviours to the
Unreleased section to make new releases easy.

## [Unreleased]

## [0.4.0] - 2021-06-09

### Fixed

- Ensured backwards compatibility with 0.2.0

## [0.3.0] - 2021-06-04

### Added

- Added support for delay exchanges to process messages after a fixed delay
- Increased documentation
- Added Warren::Message::Simple for wrapping just routing key and payload.
- Added optional worker_count to warren_consumers.yml to control number of worker threads

### Removed

- Warren::Handler::Test and Warren::Handler::Test::Channel no loner respond to
  `add_exchange`. These methods were undocumented, and unused internally.

## Changed

- Messages must now implement `#headers`, although simply returning an empty
  hash is sufficient.
  See {Warren::Message::Simple#headers} for example
- Subscriber templates now use the path 'app/warren/subscriber' rather than
  'app/warren/subscribers' to correctly match class namespacing.
- 3 consumer worker threads will be spun up by default

## [0.2.0]

### Added

- Added railties to automatically initialize and configure Warren in rails apps.
  You can remove the `config/initializers/warren.rb` and the `config.warren = config_for(:warren)`
  line from `config/application.rb`
- Added `warren config` CLI to help generate a warren.yml configuration file.
- Added warren consumers managed through `warren consumer`

## Initial release

- Import of lib/warren from sequencescape
