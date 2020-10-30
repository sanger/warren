# frozen_string_literal: true

require 'spec_helper'
require 'bunny'
require 'warren/handler/broadcast'

RSpec.describe Warren::Handler::Log do
  let(:logger) do
    spy('logger')
  end

  subject(:handler) do
    described_class.new(logger: logger, routing_key_prefix: 'test')
  end

  describe '#connect' do
    subject { handler.connect }

    it { is_expected.to be_nil }
  end

  describe '#with_channel' do
    it 'yields a channel' do
      expect { |b| handler.with_channel(&b) }.to yield_with_args(described_class::Channel)
    end
  end

  describe Warren::Handler::Log::Channel do
    let(:channel) { described_class.new(logger) }

    describe '#<<' do
      subject { channel << message }

      let(:message) { double('message', routing_key: 'key', payload: 'payload') }

      it { is_expected.to be_a(described_class) }

      it 'logs the messages' do
        channel << message
        expect(logger).to have_received(:info).with('Published: key')
        expect(logger).to have_received(:debug).with('Payload: payload')
      end
    end
  end
end
