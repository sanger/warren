# frozen_string_literal: true

require 'spec_helper'
require 'warren/handler/test'
require 'warren/broadcast_messages'
require 'helpers/dummy_active_record'

RSpec.describe Warren::BroadcastMessages do
  let(:warren) { Warren::Handler::Test.new(routing_key_prefix: 'test') }
  let(:broadcast_class) do
    Class.new(DummyActiveRecord) do
      include Warren::BroadcastMessages
    end
  end

  around do |ex|
    warren.enable!
    ex.run
    warren.disable!
  end

  before do
    mock_name = double('name', underscore: 'dummy_active_record')
    allow(broadcast_class).to receive(:name).and_return(mock_name)
  end

  context 'when using ::broadcast_via_warren' do
    let(:resource_key) { 'dummy_active_record' }
    let(:routing_key) { "test.queue_broadcast.#{resource_key}.1" }

    before do
      allow(broadcast_class).to receive(:after_commit)
      broadcast_class.broadcast_via_warren handler: warren
    end

    describe '::broadcast_via_warren' do
      it 'registers an after commit callback' do
        expect(broadcast_class).to have_received(:after_commit).with(:queue_for_broadcast)
      end

      it 'sets up a handler' do
        expect(broadcast_class.warren).to eq warren
      end
    end

    describe '#queue_for_broadcast' do
      it 'broadcasts the resource' do
        broadcast_class.new.queue_for_broadcast
        expect(warren.messages_matching(routing_key)).to eq(1)
      end
    end
  end

  context 'when using ::broadcasts_associated_via_warren' do
    before do
      allow(broadcast_class).to receive(:after_save)
      broadcast_class.broadcasts_associated_via_warren :association, handler: warren
    end

    describe '::broadcasts_associated_via_warren' do
      it 'registers an after commit callback' do
        expect(broadcast_class).to have_received(:after_save).with(:queue_associated_for_broadcast)
      end

      it 'sets up a handler' do
        expect(broadcast_class.warren).to eq warren
      end
    end

    describe '#queue_associated_for_broadcast' do
      before { warren.clear_messages }
      let(:resource) { double('associated', id: 2) }
      let(:resource_key) { 'dummy_active_record' }
      let(:routing_key) { "test.queue_broadcast.#{resource_key}.#{resource.id}" }

      it 'broadcasts the associated resource' do
        expect(resource).to receive(:try).with(:add_to_transaction)
        broadcast_class.new(association: resource).queue_associated_for_broadcast
      end
    end
  end
end
