# frozen_string_literal: true

require 'spec_helper'
require 'helpers/dummy_active_record'
require 'warren/postman'
require 'warren/subscriber/rails_base'

RSpec.describe Warren::Subscriber::RailsBase do
  subject(:subscriber) do
    delivery_info = instance_double('Bunny::DeliveryInfo', delivery_tag: 'delivery_tag', routing_key: 'test.key')
    headers = retry_attempts.zero? ? nil : { 'attempts' => retry_attempts }
    metadata = instance_double('Bunny::MessageProperties', headers: headers)
    described_class.new(postman, delivery_info, metadata, payload)
  end

  let(:postman) { instance_double('Postman', main_exchange: main_exchange) }
  let(:main_exchange) { instance_double('Postman::Channel', 'main_exchange') }
  let(:retry_attempts) { 0 }

  describe '#process' do
    before do
      allow(main_exchange).to receive(:ack)
      allow(main_exchange).to receive(:nack)
    end

    let(:record_class) { instance_double('DummyActiveRecord') }
    let(:payload) { '["DummyActiveRecord", 1]' }

    it 'acknowledges the message' do
      subscriber._process_
      expect(main_exchange).to have_received(:ack).with('delivery_tag')
    end

    # This isn't ideal, but I need time for the architecture to settle down
    # before I address this. I think its probably going to be a case of
    # separating out message processing from error handling, but given were
    # always going to need to let subscribers handle their own errors its
    # a little tricky to work out
    # rubocop:todo RSpec/SubjectStub
    it 'dead-letters the message if an exception is raised' do
      allow(subscriber).to receive(:process).and_raise(NameError,
                                                       "undefined local variable or method `bad' for main:Object'")
      subscriber._process_
      expect(main_exchange).to have_received(:nack).with('delivery_tag')
    end

    # Awaiting split for AR message base
    it 'requeues the message if a database connection exception is raised' do
      allow(subscriber).to receive(:process).and_raise(ActiveRecord::StatementInvalid,
                                                       'Mysql2::Error: MySQL server has gone away: SELECT 1')
      allow(postman).to receive(:pause!)
      subscriber._process_
      expect(main_exchange).to have_received(:nack).with('delivery_tag', false, true)
    end

    it 'pauses the postman if a database connection exception is raised' do
      allow(subscriber).to receive(:process).and_raise(ActiveRecord::StatementInvalid,
                                                       'Mysql2::Error: MySQL server has gone away: SELECT 1')
      allow(postman).to receive(:pause!)
      subscriber._process_
      expect(postman).to have_received(:pause!)
    end
    # rubocop:enable RSpec/SubjectStub
  end
end
