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

```bash
bundle install
```

Or install it yourself as:

```bash
gem install sanger_warren
```

## Usage

### Basic setup

If using with a Rails app, you can simply run `bundle exec warren config` to
help generate a warren config file. Warren will automatically be initialize
on Rails start-up.

In rails 5 you will need to add the following to your `config/application.rb`
to ensure the auto-loader can find the subscribers.

```ruby
config.autoload_paths += %W{#{Rails.root}/app}
```

### Handler types

In development mode, warren is usually configured to log to the console only. If
you wish to enable broadcast mode, the easiest way is via an environmental
variable, WARREN_TYPE.

```bash
WARREN_TYPE=broadcast bundle exec rails s
```

### Broadcasting a message

To broadcast a message, simply push the message onto the message handler

```ruby
    Warren.handler << message
```

Message should be an object that responds to routing_key and payload. The handler
will automatically prefix the routing key with the 'routing_key_prefix' configured
in the warren.yml file. By default this is usually the name of your environment.

If you are sending out multiple messages, you can check out a channel from the
connection pool, and use that instead.

```ruby
    Warren.handler.with_channel do |channel|
        channel << message_a
        channel << message_b
    end
```

### Setting up a consumer

A command line interface exists to assist with setting up consumers. It be be
invoked with:

```bash
bundle exec warren consumer add
```

This will guide you through configuration, and template out a subscriber class.
Subscribers receive the message payload, and metadata information and process
them in their #process method.

For more information about optional command line arguments you can supply to
the cli use:

```bash
bundle exec warren consumer add --help
```

#### Opinionated defaults

The cli makes some opinionated assumptions to simplify setup process:

- Consumers will use a subscriber class named Warren::Subscribed::CamelCasedConsumerName
- All consumers will dead-letter to the fanout exchange consumer-name.dead_letters
- consumer-name.dead_letters will be bound to a queue of the same name
- All queues and exchanges are durable

These options can be over-ridden in the warren_consumers.yml file if necessary.
If you wish to completely disable dead-letter queue configuration, such as when
using policies, then you can set dead_letters to false.

#### Delayed messaged

Warren uses a delay exchange / queue approach for delaying the redelivery of messages.
We don't currently support the
[delayed message exchange plugin](https://github.com/rabbitmq/rabbitmq-delayed-message-exchange)

The way this works:

- Consumers with a delay option will automatically register an exchange and a queue
- By default both of these will be named '<consumer_name>.delay' although you can
  override this by updating `warren_consumers.yml`
- The '<consumer_name>.delay' queue will have a time-to-live (ttl) set, after
  which any messages on the queue will be dead-lettered
- The dead-letter exchange for this queue is configured to an empty string `''`
  which corresponds to the 'default exchange', and the routing key is set to
  match the original queue name.
- This exchange is a little bit special, and automatically routes messages to
  any queue on the host where the queue name matches the message routing key.

This approach avoids repeat delivery of the message to any other queues bound
to the original exchange, and avoids the need for further exchanges or bindings.

### Running consumers

To run all configure consumers use:

```bash
bundle exec warren consumer start
```

You can also run only a subset of consumers:

```bash
bundle exec warren consumer start --consumers=consumer_name other_consumer
```

If you are testing in development, don't forget to set the WARREN_TYPE
environmental variable if you want to pull messages off an actual queue.

```bash
WARREN_TYPE=broadcast bundle exec warren consumer start
```

## Testing

Warren provides useful helpers to assist with testing. Helper documentation, and
some testing examples can be found in the documentation for the
{Warren::Handler::Test test helper}, or online at
[rubydoc.info](https://rubydoc.info/gems/sanger_warren/Warren/Handler/Test)

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run
`rake spec` to run the tests. You can also run `bin/console` for an interactive
prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To
release a new version, update the version number in `version.rb`, and then run
`bundle exec rake release`, which will create a git tag for the version, push
git commits and tags, and push the `.gem` file to
[rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on [GitHub](https://github.com/sanger/warren)
