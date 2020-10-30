# frozen_string_literal: true

require 'spec_helper'
require 'warren/handler/test'
require 'warren/callback/broadcast_with_warren'

RSpec.describe Warren::Callback::BroadcastWithWarren do
  let(:warren) { Warren::Handler::Test.new(routing_key_prefix: 'test') }
  let(:broadcast_class) do
    Class.new(DummyActiveRecord) do
      include Warren::Callback
    end
  end
  let(:callback) { described_class.new(handler: warren) }

  around do |ex|
    warren.enable!
    ex.run
    warren.disable!
  end

  before do
    mock_name = double('name', underscore: 'dummy_active_record')
    allow(broadcast_class).to receive(:name).and_return(mock_name)
  end

  let(:resource_key) { 'dummy_active_record' }
  let(:routing_key) { "queue_broadcast.#{resource_key}.1" }

  describe '#after_commit' do
    it 'broadcasts the resource' do
      callback.after_commit(broadcast_class.new)
      expect(warren.messages_matching(routing_key)).to eq(1)
    end
  end
end
