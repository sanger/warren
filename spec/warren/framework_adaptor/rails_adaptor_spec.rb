# frozen_string_literal: true

require 'spec_helper'
require 'active_record'
require 'warren/framework_adaptor/rails_adaptor'

RSpec.describe Warren::FrameworkAdaptor::RailsAdaptor do
  let(:connection_pool) do
    instance_double(ActiveRecord::ConnectionAdapters::ConnectionPool).tap do |pool|
      allow(pool).to receive(:with_connection).and_yield
      allow(pool).to receive(:release_connection)
    end
  end

  let(:active_record_base) do
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
    let(:adapter) { instance_double(ActiveRecord::ConnectionAdapters::AbstractAdapter) }

    before { allow(active_record_base).to receive(:connection).and_return(adapter) }

    context 'when the subscriber raises a plain StandardError (e.g. bad message logic)' do
      it 'does not capture the exception' do
        expect { described_class.new.handle { raise StandardError, 'bad logic' } }
          .to raise_error(StandardError, 'bad logic')
      end
    end

    context 'when the subscriber raises ActiveRecord::StatementInvalid (e.g. bad SQL in subscriber)' do
      it 'does not capture the exception' do
        expect { described_class.new.handle { raise ActiveRecord::StatementInvalid, 'bad sql' } }
          .to raise_error(ActiveRecord::StatementInvalid)
      end
    end

    context 'when the subscriber raises ActiveRecord::ConnectionNotEstablished' do
      it 'captures and converts to TemporaryIssue' do
        expect { described_class.new.handle { raise ActiveRecord::ConnectionNotEstablished, 'gone' } }
          .to raise_error(Warren::Exceptions::TemporaryIssue)
      end
    end

    context 'when the subscriber raises ActiveRecord::ConnectionFailed' do
      let(:exception) { ActiveRecord::ConnectionFailed.new('failed', sql: '', binds: [], connection_pool: nil) }

      it 'captures and converts to TemporaryIssue' do
        expect { described_class.new.handle { raise exception } }
          .to raise_error(Warren::Exceptions::TemporaryIssue)
      end
    end

    context 'when the subscriber raises ActiveRecord::AdapterTimeout' do
      let(:exception) { ActiveRecord::AdapterTimeout.new('timeout', sql: '', binds: [], connection_pool: nil) }

      it 'captures and converts to TemporaryIssue' do
        expect { described_class.new.handle { raise exception } }
          .to raise_error(Warren::Exceptions::TemporaryIssue)
      end
    end

    context "when we can't even check out a connection" do
      before do
        allow(active_record_base).to receive(:connection).and_raise(StandardError, 'exception depends on adapter')
      end

      it 'captures and converts to TemporaryIssue' do
        expect { described_class.new.handle { 'Nothing bad' } }.to raise_error(Warren::Exceptions::TemporaryIssue)
      end
    end
  end
end
