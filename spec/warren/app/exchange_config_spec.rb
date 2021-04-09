# frozen_string_literal: true

# require 'rails_helper'
require 'spec_helper'
require 'thor'
require 'warren/app/exchange_config'

RSpec.describe Warren::App::ExchangeConfig do
  describe '::ask' do
    let(:subject) { described_class.ask(shell) }
    let(:shell) { instance_double(Thor::Shell::Basic) }

    before do
      allow(shell).to receive(:ask).with(
        Warren::App::ExchangeConfig::EXCHANGE_PROMPT,
        limited_to: %w[d f t h n]
      ).and_return(choice, 'n')
    end

    context 'when the user chooses "direct"' do
      before do
        allow(shell).to receive(:ask).with('Specify an exchange: ').and_return('exchange_name')
        allow(shell).to receive(:ask).with('Specify a routing_key: ').and_return('key_a')
      end

      let(:choice) { 'd' }
      let(:exchange_config) do
        {
          'exchange' => { 'name' => 'exchange_name', 'options' => { type: 'direct' } },
          'options' => { routing_key: 'key_a' }
        }
      end

      it { is_expected.to eq [exchange_config] }
    end

    context 'when the user chooses "fanout"' do
      before do
        allow(shell).to receive(:ask).with('Specify an exchange: ').and_return('exchange_name')
      end

      let(:choice) { 'f' }
      let(:exchange_config) do
        {
          'exchange' => { 'name' => 'exchange_name', 'options' => { type: 'fanout' } },
          'options' => {}
        }
      end

      it { is_expected.to eq [exchange_config] }
    end

    context 'when the user chooses "topic"' do
      before do
        allow(shell).to receive(:ask).with('Specify an exchange: ').and_return('exchange_name')
        allow(shell).to receive(:ask).with('Specify a routing_key [Leave blank to stop adding]: ')
                                     .and_return('key_a', 'key_b', '')
      end

      let(:choice) { 't' }
      let(:exchange_config) do
        [{
          'exchange' => { 'name' => 'exchange_name', 'options' => { type: 'topic' } },
          'options' => { routing_key: 'key_a' }
        }, {
          'exchange' => { 'name' => 'exchange_name', 'options' => { type: 'topic' } },
          'options' => { routing_key: 'key_b' }
        }]
      end

      it { is_expected.to eq exchange_config }
    end

    context 'when the user chooses "header"' do
      before do
        allow(shell).to receive(:ask).with('Specify an exchange: ').and_return('exchange_name')
        allow(shell).to receive(:say).with('Please manually configure the arguments parameter in the yaml')
      end

      let(:choice) { 'h' }
      let(:exchange_config) do
        {
          'exchange' => { 'name' => 'exchange_name', 'options' => { type: 'header' } },
          'options' => { arguments: {} }
        }
      end

      it { is_expected.to eq [exchange_config] }
    end
  end

  describe '::parse' do
    let(:subject) { described_class.parse(shell, [choice]) }
    let(:shell) { instance_double(Thor::Shell::Basic) }

    context 'when the user chooses "direct"' do
      let(:choice) { 'direct:exchange_name:key_a' }
      let(:exchange_config) do
        {
          'exchange' => { 'name' => 'exchange_name', 'options' => { type: 'direct' } },
          'options' => { routing_key: 'key_a' }
        }
      end

      it { is_expected.to eq [exchange_config] }
    end

    context 'when the user chooses "fanout"' do
      let(:choice) { 'fanout:exchange_name' }
      let(:exchange_config) do
        {
          'exchange' => { 'name' => 'exchange_name', 'options' => { type: 'fanout' } },
          'options' => {}
        }
      end

      it { is_expected.to eq [exchange_config] }
    end

    context 'when the user chooses "topic"' do
      let(:choice) { 'topic:exchange_name:key_a,key_b' }
      let(:exchange_config) do
        [{
          'exchange' => { 'name' => 'exchange_name', 'options' => { type: 'topic' } },
          'options' => { routing_key: 'key_a' }
        }, {
          'exchange' => { 'name' => 'exchange_name', 'options' => { type: 'topic' } },
          'options' => { routing_key: 'key_b' }
        }]
      end

      it { is_expected.to eq exchange_config }
    end

    context 'when the user chooses "header"' do
      before do
        allow(shell).to receive(:say).with('Please manually configure the arguments parameter in the yaml')
      end

      let(:choice) { 'header:exchange_name' }
      let(:exchange_config) do
        {
          'exchange' => { 'name' => 'exchange_name', 'options' => { type: 'header' } },
          'options' => { arguments: {} }
        }
      end

      it { is_expected.to eq [exchange_config] }
    end

    context 'when the user chooses an invalid option' do
      let(:choice) { 'mistake:exchange_name' }

      it 'raises an error' do
        expect { described_class.parse(shell, [choice]) }.to raise_error(Thor::Error)
      end
    end
  end
end
