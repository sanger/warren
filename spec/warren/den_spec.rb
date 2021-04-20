# frozen_string_literal: true

RSpec.describe Warren::Den do
  let(:den) { described_class.new('app', config, adaptor: adaptor) }
  let(:config) { instance_spy(Warren::Config::Consumers) }
  let(:adaptor) { instance_spy(Warren::FrameworkAdaptor::RailsAdaptor) }

  describe '#fox' do
    subject { den.fox }

    before do
      allow(config).to receive(:consumer).with('app').and_return(
        'queue' => {
          'name' => 'queue_name',
          'options' => { durable: true, arguments: { 'x-dead-letter-exchange' => 'name.dead-letters' } },
          'bindings' => [
            {
              'exchange' => { 'name' => 'exchange_name', 'options' => { type: 'direct', durable: true } },
              'options' => { routing_key: 'c' }
            }
          ]
        }
      )
      allow(Warren).to receive(:handler).and_return(instance_spy(Warren::Handler::Broadcast, new_channel: true))
    end

    it { is_expected.to be_an_instance_of(Warren::Fox) }
  end
end
