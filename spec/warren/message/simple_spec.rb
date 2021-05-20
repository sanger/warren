# frozen_string_literal: true

require 'spec_helper'
require 'warren/message/simple'

RSpec.describe Warren::Message::Simple do
  subject(:message) { described_class.new('routing_key', 'payload') }

  describe '::routing_key' do
    subject { message.routing_key }

    it { is_expected.to eq 'routing_key' }
  end

  describe '::payload' do
    subject { message.payload }

    it { is_expected.to eq 'payload' }
  end

  describe '::headers' do
    subject { message.headers }

    it { is_expected.to eq(nil) }
  end
end
