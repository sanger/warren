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

If using with a Rails app, you can simply run `bundle exec warren config` to
help generate a warren config file. Warren will automatically be initialize
on Rails start-up.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/Warren.
