# frozen_string_literal: true

require 'spec_helper'
require 'warren/framework_adaptor/rails_adaptor'
require 'active_record'

RSpec.describe Warren::FrameworkAdaptor::RailsAdaptor do
  let(:active_record_base) do
    connection_pool = instance_double(ActiveRecord::ConnectionAdapters::ConnectionPool)
    allow(connection_pool).to receive(:with_connection).and_yield
    class_double(ActiveRecord::Base, connection_pool: connection_pool)
  end

  before do
    stub_const('ActiveRecord::Base', active_record_base)
  end

  describe '#recovered?' do
    subject { described_class.new.recovered? }

    context 'when we can successfully reconnect' do
      before do
        allow(active_record_base).to receive(:connection).and_return(
          instance_double(
            ActiveRecord::ConnectionAdapters::AbstractAdapter, reconnect!: nil
          )
        )
      end

      it { is_expected.to be true }
    end
  end

  describe '#handle' do
    context 'when the database is up and working' do
      let(:active_record_base) do
        connection_pool = instance_double(ActiveRecord::ConnectionAdapters::ConnectionPool)
        allow(connection_pool).to receive(:with_connection).and_yield
        class_double(ActiveRecord::Base, connection_pool: connection_pool, connected?: true)
      end

      it 'does not capture the exception' do
        expect { described_class.new.handle { raise 'Error' } }.to raise_error(StandardError, 'Error')
      end
    end

    context 'when the database is down' do
      let(:active_record_base) do
        connection_pool = instance_double(ActiveRecord::ConnectionAdapters::ConnectionPool)
        allow(connection_pool).to receive(:with_connection).and_yield
        class_double(ActiveRecord::Base, connection_pool: connection_pool, connected?: false)
      end

      it 'captures and converts the exception' do
        expect { described_class.new.handle { raise 'Error' } }.to raise_error(Warren::Exceptions::TemporaryIssue)
      end
    end
  end
end
# subject(:subscriber) do
#   delivery_info = instance_double('Bunny::DeliveryInfo', delivery_tag: 'delivery_tag', routing_key: 'test.key')
#   headers = retry_attempts.zero? ? nil : { 'attempts' => retry_attempts }
#   metadata = instance_double('Bunny::MessageProperties', headers: headers)
#   described_class.new(fox, delivery_info, metadata, payload)
# end

# let(:fox) { instance_double(Warren::Fox, subscription: subscription) }
# let(:subscription) { instance_double(Warren::Subscription, 'subscription') }
# let(:retry_attempts) { 0 }

# describe '#process' do
#   before do
#     allow(subscription).to receive(:ack)
#     allow(subscription).to receive(:nack)
#   end

#   let(:record_class) { instance_double('DummyActiveRecord') }
#   let(:payload) { '["DummyActiveRecord", 1]' }

#   it 'acknowledges the message' do
#     subscriber._process_
#     expect(subscription).to have_received(:ack).with('delivery_tag')
#   end
#   it 'dead-letters the message if an exception is raised' do
#     allow(subscriber).to receive(:process).and_raise(NameError,
#                                                      "undefined local variable or method `bad' for main:Object'")
#     subscriber._process_
#     expect(subscription).to have_received(:nack).with('delivery_tag')
#   end

#   # Awaiting split for AR message base
#   it 're-queues the message if a database connection exception is raised' do
#     allow(subscriber).to receive(:process).and_raise(ActiveRecord::StatementInvalid,
#                                                      'Mysql2::Error: MySQL server has gone away: SELECT 1')
#     allow(fox).to receive(:pause!)
#     subscriber._process_
#     expect(subscription).to have_received(:nack).with('delivery_tag', false, true)
#   end

#   it 'pauses the fox if a database connection exception is raised' do
#     allow(subscriber).to receive(:process).and_raise(ActiveRecord::StatementInvalid,
#                                                      'Mysql2::Error: MySQL server has gone away: SELECT 1')
#     allow(fox).to receive(:pause!)
#     subscriber._process_
#     expect(fox).to have_received(:pause!)
#   end
# end
