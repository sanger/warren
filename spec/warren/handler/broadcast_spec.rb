# frozen_string_literal: true

require 'spec_helper'
require 'bunny'
require 'warren/handler/broadcast'

RSpec.describe Warren::Handler::Broadcast do
  subject(:warren) do
    described_class.new(server: server_options, exchange: 'exchange', pool_size: 2, routing_key_prefix: 'test')
  end

  let(:server_options) { { heartbeat: 30, frame_max: 0 } }
  let(:bun_session) { instance_spy(Bunny::Session, create_channel: bun_channel) }
  let(:bun_channel) { instance_spy(Bunny::Channel) }
  let(:bun_exchange) { instance_spy(Bunny::Exchange) }

  before do
    allow(Bunny).to receive(:new).with(server_options).and_return(bun_session)
  end

  describe '#connect' do
    subject { warren.connect }

    it { is_expected.to eq true }

    it 'starts the bunny session' do
      warren.connect
      expect(bun_session).to have_received(:start)
    end
  end

  describe '#with_channel' do
    let(:yielded_channel) { instance_spy(described_class::Channel) }

    before do
      allow(described_class::Channel).to receive(:new)
        .with(bun_channel, exchange: 'exchange', routing_key_prefix: 'test')
        .and_return(yielded_channel)
    end

    it 'yields a channel' do
      expect { |b| warren.with_channel(&b) }.to yield_with_args(yielded_channel)
    end

    it 'starts the bunny session' do
      warren.with_channel { |_| nil }
      expect(bun_session).to have_received(:start)
    end

    it 'configures the channel' do
      warren.with_channel { |_| nil }
      expect(described_class::Channel).to have_received(:new)
        .with(bun_channel, exchange: 'exchange', routing_key_prefix: 'test')
    end
  end

  describe 'Warren::Broadcast::Channel' do
    let(:channel) do
      described_class::Channel.new(bun_channel, exchange: 'exchange', routing_key_prefix: 'test')
    end

    describe '#<<' do
      subject(:pushing_a_message) do
        channel << Warren::Message::Simple.new('key', 'payload', {})
      end

      before do
        allow(bun_channel).to receive(:exchange)
          .with('exchange', auto_delete: false, durable: true, type: :topic)
          .and_return(bun_exchange)
        allow(bun_exchange).to receive(:publish)
          .with('payload', routing_key: 'test.key', headers: {})
      end

      it { is_expected.to eq(channel) } # It allows chaining

      it 'publishes the message' do
        pushing_a_message
        expect(bun_exchange).to have_received(:publish)
          .with('payload', routing_key: 'test.key', headers: {})
      end
    end
  end
end
