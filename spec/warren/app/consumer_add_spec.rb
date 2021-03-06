# frozen_string_literal: true

require 'spec_helper'
require 'thor'
require 'yaml'
require 'warren/app/consumer_add'
require 'warren/app/consumer'
require 'helpers/configuration_helpers'

RSpec.describe Warren::App::ConsumerAdd do
  shared_examples 'a consumer addition' do
    it 'updates the configuration' do
      expect(consumer_config).to have_received(:add_consumer)
        .with('consumer_name', desc: 'my consumer', queue: 'queue_name',
                               bindings: Configuration.topic_exchange_bindings,
                               subscribed_class: 'Warren::Subscriber::ConsumerName',
                               delay: 100)
    end

    it 'saves the configuration' do
      expect(consumer_config).to have_received(:save)
    end

    it 'generates a template' do
      expect(shell).to have_received(:template).with('subscriber.tt',
                                                     'app/warren/subscriber/consumer_name.rb',
                                                     context: an_instance_of(Binding))
    end
  end

  describe '::invoke' do
    let(:shell) { instance_spy(Warren::App::Consumer) }

    let(:path) { 'tmp/test.yml' }
    let(:consumer_config) { instance_spy(Warren::Config::Consumers) }

    before do
      allow(Warren::Config::Consumers).to receive(:new).and_return(consumer_config)
      allow(consumer_config).to receive(:consumer_exist?).with('existing_consumer')
                                                         .and_return(true)
      allow(consumer_config).to receive(:consumer_exist?).with('consumer_name')
                                                         .and_return(false)
    end

    context 'with a clashing consumer name' do
      subject(:invocation) do
        described_class.invoke(shell,
                               'existing_consumer',
                               { path: path, desc: 'my consumer',
                                 # Match the format we suggest to the user in lib/warren/app/exchange_config.rb
                                 # rubocop:disable Style/FormatStringToken
                                 queue: 'queue_name', bindings: ['topic:exchange_name:%{routing_key_prefix}.c'],
                                 delay: 100 })
        # rubocop:enable Style/FormatStringToken
      end

      before do
        allow(shell).to receive(:ask).with("Consumer named 'existing_consumer' already exists. "\
                                           'Specify a alternative consumer name: ')
                                     .and_return('consumer_name')
        allow(shell).to receive(:ask).with('Provide the name of the queue to connect to: ')
                                     .and_return('queue_name')
        invocation
      end

      it 'prompts for a new name' do
        expect(shell).to have_received(:ask).with("Consumer named 'existing_consumer' already exists. "\
          'Specify a alternative consumer name: ')
      end

      it_behaves_like 'a consumer addition'
    end

    context 'with no options supplied' do
      subject(:invocation) do
        described_class.invoke(shell, nil, { path: path })
      end

      before do
        allow(shell).to receive(:ask).with('Specify a consumer name: ').and_return('consumer_name')
        allow(shell).to receive(:ask).with('Provide an optional description: ').and_return('my consumer')
        allow(shell).to receive(:ask).with('Provide the name of the queue to connect to: ').and_return('queue_name')
        allow(Warren::App::ExchangeConfig).to receive(:ask)
          .with(shell)
          .and_return(Configuration.topic_exchange_bindings)
        allow(shell).to receive(:ask).with(
          'Create a delay queue? Specify delay in milliseconds to create; set to 0 or leave blank to skip.'
        ).and_return('100')
        invocation
      end

      it 'prompts for a name' do
        expect(shell).to have_received(:ask).with('Specify a consumer name: ')
      end

      it 'prompts for a description' do
        expect(shell).to have_received(:ask).with('Provide an optional description: ')
      end

      it 'prompts for a queue' do
        expect(shell).to have_received(:ask).with('Provide the name of the queue to connect to: ')
      end

      it 'prompts for delay-queue' do
        expect(shell).to have_received(:ask).with(
          'Create a delay queue? Specify delay in milliseconds to create; set to 0 or leave blank to skip.'
        )
      end

      it 'prompts for bindings' do
        expect(Warren::App::ExchangeConfig).to have_received(:ask).with(shell)
      end

      it_behaves_like 'a consumer addition'
    end

    context 'with all options supplied' do
      subject(:invocation) do
        described_class.invoke(shell, 'consumer_name',
                               { path: path, desc: 'my consumer',
                                 # Match the format we suggest to the user in lib/warren/app/exchange_config.rb
                                 # rubocop:disable Style/FormatStringToken
                                 queue: 'queue_name', bindings: ['topic:exchange_name:%{routing_key_prefix}.c'],
                                 # rubocop:enable Style/FormatStringToken
                                 delay: 100 })
      end

      before do
        allow(Warren::App::ExchangeConfig).to receive(:ask)
        invocation
      end

      it 'does not prompt for a name' do
        expect(shell).not_to have_received(:ask).with('Specify a consumer name: ')
      end

      it 'does not prompt for a description' do
        expect(shell).not_to have_received(:ask).with('Provide an optional description: ')
      end

      it 'does not prompt for a queue' do
        expect(shell).not_to have_received(:ask).with('Provide the name of the queue to connect to: ')
      end

      it 'does not prompt for bindings' do
        expect(Warren::App::ExchangeConfig).not_to have_received(:ask)
      end

      it 'does not prompt for delay-queue' do
        expect(shell).not_to have_received(:yes?).with('Do you require a message delay queue?')
      end

      it_behaves_like 'a consumer addition'
    end
  end
end
