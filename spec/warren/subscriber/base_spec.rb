# frozen_string_literal: true

require 'spec_helper'
require 'helpers/dummy_active_record'
require 'warren/fox'
require 'warren/subscriber/base'

RSpec.describe Warren::Subscriber::Base do
  subject(:subscriber) do
    delivery_info = instance_double('Bunny::DeliveryInfo', delivery_tag: 'delivery_tag', routing_key: 'test.key')
    fox = instance_spy(Warren::Fox, subscription: subscription, error: nil)
    headers = retry_attempts.zero? ? nil : { 'attempts' => retry_attempts }
    properties = instance_double('Bunny::MessageProperties', headers: headers)
    described_class.new(fox, delivery_info, properties, payload)
  end

  before do
    allow(subscription).to receive(:ack)
    allow(subscription).to receive(:nack)
  end

  let(:subscription) { instance_spy(Warren::Subscription, 'subscription') }
  let(:retry_attempts) { 0 }

  describe '#process' do
    let(:record_class) { instance_double('DummyActiveRecord') }
    let(:payload) { '["DummyActiveRecord", 1]' }

    it 'acknowledges the message' do
      subscriber._process_
      expect(subscription).to have_received(:ack).with('delivery_tag')
    end

    it 'raises Warren::MultipleAcknowledgements if both acked and nacked' do
      subscriber.dead_letter(StandardError.new('I do not like it'))

      expect { subscriber.send(:ack) }.to raise_error(Warren::Exceptions::MultipleAcknowledgements)
    end
  end
end
