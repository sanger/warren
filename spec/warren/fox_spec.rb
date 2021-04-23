# frozen_string_literal: true

require 'logger'
require 'bunny'
require 'spec_helper'
require 'warren/fox'
require 'warren/subscription'

RSpec.describe Warren::Fox do
  subject(:fox) do
    described_class.new(name: 'fox', subscription: subscription, adaptor: adaptor,
                        subscribed_class: Warren::Subscriber::Base)
  end

  let(:subscription) { instance_spy(Warren::Subscription) }
  let(:consumer) { instance_spy(Bunny::Consumer) }
  let(:adaptor) { instance_spy(Warren::FrameworkAdaptor::RailsAdaptor, logger: instance_spy(Logger)) }

  before do
    allow(subscription).to receive(:activate!)
    allow(subscription).to receive(:subscribe).and_return(consumer)
  end

  describe '#run!' do
    it 'registers its queues' do
      fox.run!
      expect(subscription).to have_received(:activate!)
    end

    it 'subscribes to queues' do
      fox.run!
      expect(subscription).to have_received(:subscribe).with(fox.consumer_tag)
    end

    it 'is running' do
      fox.run!
      expect(fox).to be_running
    end
  end

  describe '#stop!' do
    before { fox.run! }

    it 'unsubscribes from queues' do
      fox.stop!
      expect(consumer).to have_received(:cancel)
    end

    it 'is stopped' do
      fox.stop!
      expect(fox).to be_stopped
    end
  end

  describe '#pause!' do
    before { fox.run! }

    it 'unsubscribes from queues' do
      fox.pause!
      expect(consumer).to have_received(:cancel)
    end

    it 'is paused' do
      fox.pause!
      expect(fox).to be_paused
    end

    it 'is due recovery' do
      fox.pause!
      expect(fox.send(:recovery_due?)).to be true
    end
  end

  # Process is triggered via the subscription.
  describe '#process' do
    before do
      allow(subscription).to receive(:subscribe).and_return(consumer).and_yield(delivery_info, 'y', 'z')
      allow(adaptor).to receive(:handle).and_yield
      allow(Warren::Subscriber::Base).to receive(:new).with(fox, delivery_info, 'y', 'z').and_return(message)
    end

    let(:delivery_info) { instance_double('Bunny::DeliveryInfo', delivery_tag: 'delivery_tag') }
    let(:message) { instance_spy(Warren::Subscriber::Base) }

    it 'processes the messages' do
      fox.run!
      expect(message).to have_received(:_process_)
    end

    context 'when message processing fails' do
      it 'dead-letters the message' do
        allow(message).to receive(:_process_).and_raise(NameError, 'message error')
        fox.run!
        expect(message).to have_received(:dead_letter).with(instance_of(NameError))
      end

      # Awaiting split for AR message base
      it 're-queues the message if a database connection exception is raised' do
        allow(adaptor).to receive(:handle).and_raise(Warren::Exceptions::TemporaryIssue)
        fox.run!
        expect(message).to have_received(:requeue).with(instance_of(Warren::Exceptions::TemporaryIssue))
      end

      it 'pauses the fox if a database connection exception is raised' do
        allow(adaptor).to receive(:handle).and_raise(Warren::Exceptions::TemporaryIssue)
        fox.run!
        expect(fox).to be_paused
      end
    end
  end

  describe 'attempt_recovery' do
    context 'when running normally' do
      before { fox.run! }

      it 'does nothing' do
        expect(fox.attempt_recovery).to eq nil
      end
    end

    context 'when paused' do
      before do
        fox.run!
        fox.pause!
      end

      it 'attempts recovery' do
        fox.attempt_recovery
        expect(adaptor).to have_received(:recovered?)
      end

      it 'resubscribes once recovered' do
        allow(adaptor).to receive(:recovered?).and_return(true)
        fox.attempt_recovery
        # Twice as also se the original subscription
        expect(subscription).to have_received(:subscribe).with(fox.consumer_tag).twice
      end

      it 'is running once recovered' do
        allow(adaptor).to receive(:recovered?).and_return(true)
        fox.attempt_recovery
        expect(fox).to be_running
      end

      it 'remains paused if not recovered' do
        allow(adaptor).to receive(:recovered?).and_return(false)
        fox.attempt_recovery
        # Twice as also se the original subscription
        expect(fox).to be_paused
      end
    end
  end
end
