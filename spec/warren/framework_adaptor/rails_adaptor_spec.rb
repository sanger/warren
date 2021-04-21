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
