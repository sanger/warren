# frozen_string_literal: true

# When testing the ActiveRecord integrations we want a class that mimics some
# of the functionality of ActiveRecord::Base
class DummyActiveRecord
  # Include our callback methods
  include Warren::Callback

  attr_reader :id, :association

  def self.after_commit(args)
    # Usually supplied by rails
  end

  def self.after_save(args); end

  def self.name
    'DummyActiveRecord'
  end

  def to_json(_)
    '{id:1}'
  end

  def initialize(id: 1, association: nil)
    @id = id
    @association = association
  end
end

# NOTE: I want to try and avoid bringing in active record as a developmental
# dependency for the core tests. However we probably DO want active record
# loaded for testing our integrations. I'm mocking this at the moment though
# as I really want to get to a situation where I have something functional to
# build upon.
unless defined?(ActiveRecord::StatementInvalid)
  module ActiveRecord
    StatementInvalid = Class.new(StandardError)
  end
end
