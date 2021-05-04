# frozen_string_literal: true

require 'spec_helper'
require 'warren/config/consumers'
require 'helpers/configuration_helpers'

RSpec.describe Warren::Config::Consumers do
  let(:path) { 'tmp/test.yml' }
  let(:consumers) { described_class.new(path) }

  before do
    allow(YAML).to receive(:load_file)
      .with(path)
      .and_return('existing_consumer' => {})
  end

  describe '#consumer_exist?' do
    subject { consumers.consumer_exist?(name) }

    context 'when it exists' do
      let(:name) { 'existing_consumer' }

      it { is_expected.to be true }
    end

    context 'when it does not exists' do
      let(:name) { 'novel_consumer' }

      it { is_expected.to be false }
    end
  end

  describe '#add_consumer' do
    subject(:add_consumer) do
      consumers.add_consumer('name', desc: 'description', queue: 'queue_name',
                                     bindings: Configuration.topic_exchange_bindings,
                                     subscribed_class: 'Warren::Subscriber::Name')
    end

    let(:expected_config) do
      Configuration.topic_exchange_consumer
    end

    it 'returns a consumer config hash' do
      expect(add_consumer).to eq(expected_config)
    end

    it 'registers the consumer' do
      add_consumer
      expect(consumers.consumer_exist?('name')).to be true
    end
  end

  describe '#save' do
    let(:file) { instance_double(File, write: 20) }
    let(:expected_payload) do
      satisfy('a valid yaml file') do |v|
        YAML.safe_load(v, permitted_classes: [Symbol]) == Configuration.warren_consumers
      end
    end

    before do
      allow(File).to receive(:open).with(path, 'w').and_yield(file)
      consumers.add_consumer('name', desc: 'description', queue: 'queue_name',
                                     bindings: Configuration.topic_exchange_bindings,
                                     subscribed_class: 'Warren::Subscriber::Name')
      consumers.save
    end

    it 'save the yaml' do
      expect(file).to have_received(:write).with(expected_payload)
    end
  end

  describe '#consumer' do
    subject(:consumer) { consumers.consumer(name) }

    context 'when it exists' do
      let(:name) { 'existing_consumer' }

      it { is_expected.to eq({}) }
    end

    context 'when it does not exist' do
      let(:name) { 'non_existing_consumer' }

      it 'raises an exception' do
        expect { consumer }.to raise_error(StandardError, "Unknown consumer 'non_existing_consumer'")
      end
    end
  end
end
