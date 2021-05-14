# frozen_string_literal: true

require 'spec_helper'
require 'multi_json'
require 'warren/message/full'

# Note this test dependent on ActiveSupport
RSpec.describe Warren::Message::Full do
  subject(:message) { described_class.new(DummyActiveRecord.new) }

  describe '::routing_key' do
    subject { message.routing_key }

    it { is_expected.to eq 'saved.dummy_active_record.1' }
  end

  describe '::payload' do
    subject { message.payload }

    it { is_expected.to eq '{id:1}' }
  end

  describe '::headers' do
    subject { message.headers }

    it { is_expected.to eq({}) }
  end
end
