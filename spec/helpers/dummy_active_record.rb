# frozen_string_literal: true

# When testing the ActiveRecord integrations we want a class that mimics some
# of the functionality of ActiveRecord::Base
class DummyActiveRecord
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
