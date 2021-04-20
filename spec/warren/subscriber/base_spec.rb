# frozen_string_literal: true

require 'spec_helper'
require 'helpers/dummy_active_record'
require 'warren/fox'
require 'warren/subscriber/base'

RSpec.describe Warren::Subscriber::Base do
  subject(:subscriber) do
    delivery_info = instance_double('Bunny::DeliveryInfo', delivery_tag: 'delivery_tag', routing_key: 'test.key')
    fox = instance_double(Warren::Fox, subscription: subscription)
    headers = retry_attempts.zero? ? nil : { 'attempts' => retry_attempts }
    metadata = instance_double('Bunny::MessageProperties', headers: headers)
    described_class.new(fox, delivery_info, metadata, payload)
  end

  before do
    allow(subscription).to receive(:ack)
    allow(subscription).to receive(:nack)
  end

  let(:subscription) { instance_double(Warren::Subscription, 'subscription') }
  let(:retry_attempts) { 0 }

  describe '#process' do
    let(:record_class) { instance_double('DummyActiveRecord') }
    let(:payload) { '["DummyActiveRecord", 1]' }

    it 'acknowledges the message' do
      subscriber._process_
      expect(subscription).to have_received(:ack).with('delivery_tag')
    end
  end
end
