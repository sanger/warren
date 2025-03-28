# frozen_string_literal: true

require 'spec_helper'
require 'warren/handler/broadcast'
require 'warren/delay_exchange'
require 'helpers/configuration_helpers'

RSpec.describe Warren::DelayExchange do
  subject(:delay_exchange) do
    described_class.new(channel: channel, config: config)
  end

  let(:config) do
    Configuration.delay_exchange_configuration(exchange_name: 'exchange_name', queue_name: 'queue_name')
  end

  let(:queue) { instance_spy(Bunny::Queue) }
  let(:channel) { instance_spy(Warren::Handler::Broadcast::Channel, queue: queue, routing_key_prefix: 'test') }
  let(:queue_options) do
    {
      durable: true,
      arguments: { 'x-dead-letter-exchange' => '', 'x-message-ttl' => 30_000,
                   'x-dead-letter-routing-key' => 'queue_name' }
    }
  end

  describe '#activate!' do
    let(:exchange) { instance_spy(Bunny::Exchange) }

    before do
      allow(channel).to receive(:exchange).and_return(exchange)
      delay_exchange.activate!
    end

    it 'registers a queue' do
      expect(channel).to have_received(:queue).with('queue_name', queue_options)
    end

    it 'registers an exchange' do
      expect(channel).to have_received(:exchange).with('exchange_name', type: 'fanout', durable: true)
    end

    it 'registers bindings' do
      expect(queue).to have_received(:bind).with(exchange, {})
    end

    context 'when not configured' do
      let(:config) { nil }

      it 'does nothing', aggregate_failures: true do
        expect(channel).not_to have_received(:queue)
        expect(channel).not_to have_received(:exchange)
        expect(queue).not_to have_received(:bind)
      end
    end
  end

  describe '#publish' do
    let(:exchange) { instance_spy(Bunny::Exchange) }

    before do
      allow(channel).to receive(:publish).and_return(channel)
      delay_exchange.publish('payload', routing_key: 'original_routing_key')
    end

    it 'sends a message' do
      expect(channel).to have_received(:publish).with(
        have_attributes(payload: 'payload', routing_key: 'original_routing_key', headers: {}),
        exchange: delay_exchange.send(:exchange)
      )
    end
  end
end
