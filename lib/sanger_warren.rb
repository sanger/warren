# frozen_string_literal: true

# While the gem is sanger_warren we actually namespace under Warren.
# The gem 'warren' performs a very similar function, but hasn't been updated
# for ten years.
# We need to include this file to ensure bundler automatically requires warren,
# thereby triggering the railties
require 'warren'
