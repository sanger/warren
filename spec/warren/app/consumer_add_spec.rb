# frozen_string_literal: true

require 'spec_helper'
require 'warren/app/consumer_add'
require 'yaml'

RSpec.describe Warren::App::ConsumerAdd do
  describe '::invoke' do
    subject(:invocation) { described_class.invoke(shell, path: path, exchange: 'exchange') }

    it 'will be tested' do
      value = true
      expect(value).to be true
    end
  end
end
