# frozen_string_literal: true

require 'spec_helper'
require 'thor'
require 'yaml'
require 'warren/app/consumer_add'

RSpec.describe Warren::App::ConsumerAdd do
  describe '::invoke' do
    let(:shell) { instance_double(Thor::Shell::Basic) }
    let(:expected_payload) do
      parsed_yaml = {
        'existing_consumer' => {},
        'consumer_name' => {
          'desc' => 'my consumer',
          'queue' => {
            'name' => 'queue_name',
            'options' => { 'durable' => true },
            'bindings' => [
              {
                'exchange' => { 'name' => 'exchange_name', 'type' => 'direct' },
                'options' => { routing_key: 'c' }
              }
            ]
          }
        }
      }
      satisfy('a valid yaml file') { |v| YAML.safe_load(v, permitted_classes: [Symbol]) == parsed_yaml }
    end
    let(:path) { 'tmp/test.yml' }
    let(:file) { instance_double(File, write: 20) }

    before do
      allow(YAML).to receive(:load_file)
        .with(path)
        .and_return({
                      'existing_consumer' => {}
                    })
      allow(File).to receive(:open).with(path, 'w').and_yield(file)
    end

    shared_examples 'a consumer addition' do
      it 'updates the configuration' do
        expect(file).to have_received(:write).with(expected_payload)
      end
    end

    context 'with a clashing consumer name' do
      subject(:invocation) do
        described_class.invoke(shell,
                               'existing_consumer',
                               { path: path, desc: 'my consumer',
                                 queue: 'queue_name', bindings: ['direct:exchange_name:c'] })
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
          .and_return([{
                        'exchange' => { 'name' => 'exchange_name', 'type' => 'direct' },
                        'options' => { routing_key: 'c' }
                      }])
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

      it 'prompts for bindings' do
        expect(Warren::App::ExchangeConfig).to have_received(:ask).with(shell)
      end

      it_behaves_like 'a consumer addition'
    end

    context 'with all options supplied' do
      subject(:invocation) do
        described_class.invoke(shell, 'consumer_name',
                               { path: path, desc: 'my consumer',
                                 queue: 'queue_name', bindings: ['direct:exchange_name:c'] })
      end

      before do
        allow(shell).to receive(:ask).with('Specify a consumer name: ')
        allow(shell).to receive(:ask).with('Provide an optional description: ')
        allow(shell).to receive(:ask).with('Provide the name of the queue to connect to: ')
        allow(Warren::App::ExchangeConfig).to receive(:ask).with(shell)
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
        expect(Warren::App::ExchangeConfig).not_to have_received(:ask).with(shell)
      end

      it_behaves_like 'a consumer addition'
    end
  end
end
