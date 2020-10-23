# frozen_string_literal: true

require 'spec_helper'
require 'warren/handler/test'
require 'warren/callback'
require 'helpers/dummy_active_record'

RSpec.describe Warren::Callback do
  let(:warren) { Warren::Handler::Test.new(routing_key_prefix: 'test') }
  let(:broadcast_class) do
    Class.new(DummyActiveRecord) do
      include Warren::Callback
    end
  end

  before do
    mock_name = double('name', underscore: 'dummy_active_record')
    allow(broadcast_class).to receive(:name).and_return(mock_name)
  end

  describe '::broadcast_via_warren' do
    let(:callback_class) { Warren::Callback::BroadcastViaWarren }

    before do
      allow(broadcast_class).to receive(:after_commit)
      broadcast_class.broadcast_via_warren handler: warren
    end

    it 'registers an after commit callback' do
      expect(broadcast_class).to have_received(:after_commit).with(instance_of(callback_class))
                                                             .with(have_attributes(handler: warren))
    end
  end

  describe '::broadcasts_associated_via_warren' do
    let(:callback_class) { Warren::Callback::BroadcastAssociatedViaWarren }

    before do
      allow(broadcast_class).to receive(:after_save)
      broadcast_class.broadcasts_associated_via_warren :association, handler: warren
    end

    it 'registers an after save callback' do
      expect(broadcast_class).to have_received(:after_save).with(instance_of(callback_class))
                                                           .with(have_attributes(associations: [:association],
                                                                                 handler: warren))
    end
  end
end
