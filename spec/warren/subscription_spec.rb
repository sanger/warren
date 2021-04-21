# frozen_string_literal: true

require 'spec_helper'
require 'warren/handler/broadcast'

RSpec.describe Warren::Subscription do
  subject(:subscription) do
    described_class.new(
      channel: channel,
      config: {
        'name' => 'test',
        'options' => queue_options,
        'bindings' => [
          {
            'exchange' => { 'name' => 'amqp.direct', 'options' => { type: 'direct' } },
            'options' => { routing_key: 'key' }
          }
        ],
        'subscribed_class' => 'Warren::Subscriber::Base'
      }
    )
  end

  let(:queue) { instance_spy(Bunny::Queue) }
  let(:channel) { instance_spy(Warren::Handler::Broadcast::Channel, queue: queue) }
  let(:queue_options) do
    {
      durable: true,
      arguments: { 'x-dead-letter-exchange' => 'warren_test.dead-letters' }
    }
  end

  describe '#subscribe' do
    before { subscription.subscribe('test_fox') { true } }

    it 'sets a prefetch' do
      expect(channel).to have_received(:prefetch).with(10)
    end

    it 'registers a queue' do
      expect(channel).to have_received(:queue).with('test', queue_options)
    end

    it 'subscribes to the queue' do
      expect(queue).to have_received(:subscribe).with(
        manual_ack: true, block: false, consumer_tag: 'test_fox', durable: true
      )
    end
  end

  describe '#activate!' do
    let(:exchange) { instance_double(Bunny::Exchange) }

    before do
      allow(channel).to receive(:exchange).and_return(exchange)
      subscription.activate!
    end

    it 'registers a queue' do
      expect(channel).to have_received(:queue).with('test', queue_options)
    end

    it 'registers an exchange' do
      expect(channel).to have_received(:exchange).with('amqp.direct', type: 'direct')
    end

    it 'registers bindings' do
      expect(queue).to have_received(:bind).with(exchange, routing_key: 'key')
    end
  end

  describe '#subscribed_class' do
    subject { subscription.subscribed_class }

    it { is_expected.to eq Warren::Subscriber::Base }
  end
end
