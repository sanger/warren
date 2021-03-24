# frozen_string_literal: true

require 'spec_helper'
require 'warren/handler/test'
require 'warren/callback/broadcast_associated_with_warren'

RSpec.describe Warren::Callback::BroadcastAssociatedWithWarren do
  let(:warren) { Warren::Handler::Test.new(routing_key_prefix: 'test') }
  let(:broadcast_class) do
    Class.new(DummyActiveRecord) do
      include Warren::Callback
    end
  end
  let(:callback) { described_class.new([:association], handler: warren) }

  around do |ex|
    warren.enable!
    ex.run
    warren.disable!
  end

  before do
    mock_name = double('name', underscore: 'dummy_active_record') # rubocop:todo RSpec/VerifiedDoubles
    allow(broadcast_class).to receive(:name).and_return(mock_name)
  end

  describe '#after_save' do # rubocop:todo RSpec/MultipleMemoizedHelpers
    before { warren.clear_messages }

    let(:resource) { double('associated', id: 2) } # rubocop:todo RSpec/VerifiedDoubles
    let(:resource_key) { 'dummy_active_record' }
    let(:routing_key) { "test.queue_broadcast.#{resource_key}.#{resource.id}" }

    it 'broadcasts the associated resource' do
      expect(resource).to receive(:try).with(:add_to_transaction) # rubocop:todo RSpec/MessageSpies
      callback.after_save(broadcast_class.new(association: resource))
    end
  end
end
