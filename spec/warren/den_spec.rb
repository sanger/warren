# frozen_string_literal: true

require 'warren/den'
require 'warren/config/consumers'
require 'helpers/configuration_helpers'

RSpec.describe Warren::Den do
  let(:den) { described_class.new('app', config, adaptor: adaptor) }
  let(:config) { instance_spy(Warren::Config::Consumers) }
  let(:adaptor) { instance_spy(Warren::FrameworkAdaptor::RailsAdaptor) }
  let(:channel) { instance_spy(Warren::Handler::Broadcast::Channel) }

  before do
    consumer_config = Configuration.topic_exchange_consumer(subscribed_class: 'Warren::Subscriber::Base')
    allow(config).to receive(:consumer).with('app')
                                       .and_return(consumer_config)
    allow(Warren).to receive(:handler).and_return(instance_spy(Warren::Handler::Broadcast, new_channel: channel))
  end

  describe '#fox' do
    subject { den.fox }

    it { is_expected.to be_an_instance_of(Warren::Fox) }
  end

  describe '#register_dead_letter_queues' do
    let(:subscription) { instance_spy(Warren::Subscription) }

    before do
      allow(Warren::Subscription).to receive(:new).with(
        channel: channel,
        config: Configuration.dead_letter_configuration
      ).and_return(subscription)
    end

    it 'activates a subscription' do
      den.register_dead_letter_queues
      expect(subscription).to have_received(:activate!)
    end
  end
end
