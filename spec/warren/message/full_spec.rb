# frozen_string_literal: true

require 'spec_helper'
require 'multi_json'
require 'warren/message/full'

RSpec.describe Warren::Message::Full do
  subject(:message) { described_class.new(DummyActiveRecord.new) }

  before do
    mock_name = double('name', underscore: 'dummy_active_record', to_s: 'DummyActiveRecord')
    allow(DummyActiveRecord).to receive(:name).and_return(mock_name)
  end

  describe '::routing_key' do
    subject { message.routing_key }
    it { is_expected.to eq 'saved.dummy_active_record.1' }
  end

  describe '::payload' do
    subject { message.payload }
    it { is_expected.to eq '{id:1}' }
  end
end
