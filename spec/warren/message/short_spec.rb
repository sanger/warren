# frozen_string_literal: true

require 'spec_helper'
require 'warren/message/short'

RSpec.describe Warren::Message::Short do
  subject(:message) { described_class.new(DummyActiveRecord.new) }

  describe '::routing_key' do
    subject { message.routing_key }

    it { is_expected.to eq 'queue_broadcast.dummy_active_record.1' }
  end

  describe '::payload' do
    subject { message.payload }

    it { is_expected.to eq '["DummyActiveRecord",1]' }
  end
end
