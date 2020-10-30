# Warren

Warren extracts the connection pooling behaviour originally in Sequencescape
in order to provide a common interface for our Rails app interaction with
RabbitMQ via the bunny gem.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'sanger-warren'
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install sanger-warren

## Usage

If using with a Rails app, here's an example to get you started:

```ruby
# config/initializers/warren.rb
require 'warren'

Warren.setup(Rails.application.config.warren.deep_symbolize_keys.slice(:type, :config))
```

```ruby
# config/application.rb
# ...
config.warren = config_for(:warren)
# ...
```

```yaml
# config/warren.yml
development:
  type: log
  config: # Useful to allow easy switching to broadcast in development
    routing_key_prefix: 'dev'
    server:
      host: localhost
      port: 5672
      username: guest
      password: guest
      vhost: /
      frame_max: 0
      heartbeat: 30
    exchange: exchange_to_use
test:
  type: test
production: # In practice keep this out of your source control
  type: broadcast
  config: # Useful to allow easy switching to broadcast
    routing_key_prefix: 'production'
    server:
      host: localhost # Or a remote host
      port: 5672
      username: ...
      password: ...
      vhost: /
      frame_max: 0
      heartbeat: 30
    exchange: exchange_to_use
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/Warren.
