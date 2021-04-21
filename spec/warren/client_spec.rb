# frozen_string_literal: true

require 'logger'
require 'spec_helper'
require 'warren/client'
require 'warren/config/consumers'
require 'warren/handler/broadcast'

RSpec.describe Warren::Client do
  let(:config) { instance_double(Warren::Config::Consumers) }
  let(:client) { described_class.new(config, consumers: consumers) }

  # Some helper methods to assist with setup
  def mock_den(consumer_name, fox)
    allow(Warren::Den).to receive(:new)
      .with(consumer_name, config, adaptor: be_an_instance_of(Warren::FrameworkAdaptor::RailsAdaptor))
      .and_return(instance_double(Warren::Den, fox: fox))
  end

  def run_client(client)
    # Mock alive so that the control loop terminates after one loop
    allow(client).to receive(:alive?).and_return(true, false)
    allow(client).to receive(:sleep).with(3) # Disable the sleep for performance
    client.run
  end

  # We don't have very many publicly expose methods here, run essentially
  # handles most of what we want. We'll also need to test our termination
  describe '#run' do
    let(:handler) { instance_double(Warren::Handler::Broadcast, connect: true) }

    before do
      allow(Warren).to receive(:handler).and_return(handler)
    end

    context 'with a single consumer' do
      let(:consumers) { ['consumer_a'] }
      let(:fox) { instance_double(Warren::Fox, run!: true, attempt_recovery: true) }

      before do
        mock_den('consumer_a', fox)
        run_client(client)
      end

      it 'runs the fox' do
        expect(fox).to have_received(:run!)
      end

      it 'initializes the handler' do
        expect(handler).to have_received(:connect)
      end

      it 'enters a control loop' do
        expect(fox).to have_received(:attempt_recovery)
      end
    end

    context 'with all consumers' do
      let(:consumers) { nil }
      let(:fox) do
        [
          instance_double(Warren::Fox, run!: true, attempt_recovery: true),
          instance_double(Warren::Fox, run!: true, attempt_recovery: true)
        ]
      end

      before do
        allow(config).to receive(:all_consumers).and_return(%w[consumer_a consumer_b])
        mock_den('consumer_a', fox[0])
        mock_den('consumer_b', fox[1])
        run_client(client)
      end

      it 'runs the foxes' do
        expect(fox).to all(have_received(:run!))
      end

      it 'enters a control loop' do
        expect(fox).to all(have_received(:attempt_recovery))
      end
    end
  end

  describe '#stop!' do
    before do
      handler = instance_double(Warren::Handler::Broadcast, connect: true)
      allow(Warren).to receive(:handler).and_return(handler)
    end

    context 'with a single consumer' do
      let(:consumers) { ['consumer_a'] }
      let(:fox) { instance_double(Warren::Fox, run!: true, attempt_recovery: true, stop!: true) }

      before do
        mock_den('consumer_a', fox)
        allow(client).to receive(:sleep).with(3) # Disable the sleep for performance
      end

      it 'stops the process' do
        thread = Thread.new { client.run }
        # Wait until the client is running
        Timeout.timeout(2) { nil until client.started? }
        client.stop!
        Timeout.timeout(2) { nil until client.stopped? }
        expect(thread).to be_stop
      end

      it 'stops the foxes' do
        Thread.new { client.run }
        # Wait until the client is running
        Timeout.timeout(2) { nil until client.started? }
        client.stop!
        Timeout.timeout(2) { nil until client.stopped? }
        expect(fox).to have_received(:stop!)
      end
    end
  end
end
