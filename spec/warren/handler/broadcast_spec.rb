# frozen_string_literal: true

require 'spec_helper'
require 'bunny'
require 'warren/handler/broadcast'

RSpec.describe Warren::Handler::Broadcast do
  subject(:warren) do
    described_class.new(server: server_options, exchange: 'exchange', pool_size: 2, routing_key_prefix: 'test')
  end

  let(:server_options) { { heartbeat: 30, frame_max: 0 } }
  let(:bunny_session) { instance_spy(Bunny::Session, create_channel: bun_channel) }
  let(:bun_channel) { instance_spy(Bunny::Channel) }
  let(:bun_exchange) { instance_spy(Bunny::Exchange) }

  before do
    allow(Bunny).to receive(:new).with(server_options).and_return(bunny_session)
  end

  describe '#connect' do
    subject { warren.connect }

    it { is_expected.to eq true }

    it 'starts the bunny session' do
      warren.connect
      expect(bunny_session).to have_received(:start)
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
      expect(bunny_session).to have_received(:start)
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

  describe '#start_session' do
    # Helper for setting up failures for testing retry logic.
    # @param failures [Integer] The number of times to fail
    # @param exception_class [Class] The exception class to raise (default: Bunny::Exception)
    # @return [Integer] The number of times start was called
    def stub_bunny_start_failures(failures: 2, exception_class: Bunny::Exception)
      call_count = 0
      allow(bunny_session).to receive(:start) do
        call_count += 1
        raise exception_class, 'test error' if call_count <= failures

        bunny_session
      end
      call_count
    end

    let(:bunny_session) { instance_spy(Bunny::Session) }

    before do
      allow(Bunny).to receive(:new).and_return(bunny_session)
      # Prevent actual sleeping and output during tests.
      allow($stdout).to receive(:puts)
      allow_any_instance_of(described_class).to receive(:sleep) # rubocop:disable RSpec/AnyInstance
    end

    it 'returns true when session starts' do
      allow(bunny_session).to receive(:start).and_return(bunny_session)
      expect(warren.send(:start_session)).to eq true
    end

    it 'calls start once when session starts on the first try' do
      allow(bunny_session).to receive(:start).and_return(bunny_session)
      warren.send(:start_session)
      expect(bunny_session).to have_received(:start).once
    end

    it 'retries and eventually succeeds' do
      stub_bunny_start_failures(failures: 2)
      expect(warren.send(:start_session)).to eq true
    end

    it 'retries instead of raising exception' do
      stub_bunny_start_failures(failures: 3)
      expect { warren.send(:start_session) }.not_to raise_error
    end

    it 'calls start multiple times when retrying' do
      stub_bunny_start_failures(failures: 4)
      warren.send(:start_session)
      # Success on the 5th attempt
      expect(bunny_session).to have_received(:start).exactly(5).times
    end

    it 'outputs retry message to $stdout' do
      stub_bunny_start_failures(failures: 6)
      expect { warren.send(:start_session) }.to output(/retrying in \d+s/).to_stdout
    end

    it 'raises exception after retrying the maximum number of attempts' do
      stub_bunny_start_failures(failures: described_class::MAX_START_SESSION_ATTEMPTS)
      expect { warren.send(:start_session) }.to raise_error(Warren::Exceptions::SessionStartError)
    end

    it 'calls start no more than the maximum number of attempts' do # rubocop:disable RSpec/MultipleExpectations
      stub_bunny_start_failures(failures: described_class::MAX_START_SESSION_ATTEMPTS)
      expect { warren.send(:start_session) }.to raise_error(Warren::Exceptions::SessionStartError)
      expect(bunny_session).to have_received(:start).exactly(described_class::MAX_START_SESSION_ATTEMPTS).times
    end

    it 'raises exception with the correct error message' do
      stub_bunny_start_failures(failures: described_class::MAX_START_SESSION_ATTEMPTS)
      expect do
        warren.send(:start_session)
      end.to raise_error(Warren::Exceptions::SessionStartError,
                         /Failed to start session \(Bunny::Exception\): test error, attempts: 30, giving up\./)
    end

    # Test that all handled exceptions trigger retries and raise exception after max attempts.
    # Bunny::Exception is the top-level exception for Bunny errors
    # Errno exceptions cover any exception that bubbles up from sockets.
    # The code covers almost all possible exceptions that could be raised during
    # connection attempts, but we can add more if needed and test here.
    # rubocop:disable RSpec/MultipleExpectations, RSpec/ExampleLength
    [Bunny::Exception, Errno::ECONNREFUSED, Errno::ETIMEDOUT].each do |exception_class|
      it "retries start and raises exception for #{exception_class}" do
        stub_bunny_start_failures(
          failures: described_class::MAX_START_SESSION_ATTEMPTS,
          exception_class: exception_class
        )
        expect do
          warren.send(:start_session)
        end.to raise_error(
          Warren::Exceptions::SessionStartError,
          /Failed to start session \(#{exception_class}\): .*test error, attempts: 30, giving up\./
        )
        expect(bunny_session).to have_received(:start)
          .exactly(described_class::MAX_START_SESSION_ATTEMPTS).times
      end
    end
    # rubocop:enable RSpec/MultipleExpectations, RSpec/ExampleLength
  end
end
