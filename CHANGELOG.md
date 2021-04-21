# Changelog

Keeps track of notable changes. Please remember to add new behaviours to the
Unreleased section to make new releases easy.

## [Unreleased]
### Added

- Added railties to automatically initialize and configure Warren in rails apps.
  You can remove the `config/initializers/warren.rb` and the `config.warren = config_for(:warren)`
  line from `config/application.rb`
- Added `warren config` CLI to help generate a warren.yml configuration file.
- Added warren consumers managed through `warren consumer`

## Initial release

- Import of lib/warren from sequencescape
