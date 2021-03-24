# frozen_string_literal: true

require 'warren'

RSpec.describe Warren do
  it 'has a version number' do
    expect(Warren::VERSION).not_to be nil
  end

  describe '::construct' do
    subject { described_class.construct(type: type, config: config) }

    context 'when type is log' do
      let(:type) { 'log' }
      let(:logger) { double('logger') } # rubocop:todo RSpec/VerifiedDoubles
      let(:config) { { logger: logger, routing_key_prefix: 'test' } }

      it { is_expected.to be_a Warren::Handler::Log }
      it { is_expected.to have_attributes(logger: logger) }
    end

    context 'when type is test' do
      let(:type) { 'test' }
      let(:config) { {} }

      it { is_expected.to be_a Warren::Handler::Test }
    end

    context 'when type is broadcast' do
      let(:type) { 'broadcast' }
      let(:config) { { exchange: 'test', routing_key_prefix: 'test' } }

      it { is_expected.to be_a Warren::Handler::Broadcast }
    end
  end
end
