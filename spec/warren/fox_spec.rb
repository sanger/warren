# frozen_string_literal: true

require 'logger'
require 'bunny'
require 'digest'
require 'spec_helper'
require 'warren/fox'
require 'warren/subscription'

RSpec.describe Warren::Fox do
  subject(:fox) do
    described_class.new(name: 'fox', subscription: subscription, adaptor: adaptor,
                        subscribed_class: Warren::Subscriber::Base, delayed: delayed)
  end

  let(:subscription) { instance_spy(Warren::Subscription, subscribe: consumer) }
  let(:delayed) { instance_spy(Warren::Subscription) }
  let(:consumer) { instance_spy(Bunny::Consumer) }
  let(:adaptor) { instance_spy(Warren::FrameworkAdaptor::RailsAdaptor, logger: instance_spy(Logger)) }

  describe '#run!' do
    before { fox.run! }

    it 'registers its queues' do
      expect(subscription).to have_received(:activate!)
    end

    it 'subscribes to queues' do
      expect(subscription).to have_received(:subscribe).with(fox.consumer_tag)
    end

    it 'is running' do
      expect(fox).to be_running
    end
  end

  describe '#stop!' do
    before do
      fox.run!
      fox.stop!
    end

    it 'unsubscribes from queues' do
      expect(consumer).to have_received(:cancel)
    end

    it 'is stopped' do
      expect(fox).to be_stopped
    end
  end

  describe '#pause!' do
    before do
      fox.run!
      fox.pause!
    end

    it 'unsubscribes from queues' do
      expect(consumer).to have_received(:cancel)
    end

    it 'is paused' do
      expect(fox).to be_paused
    end

    it 'is due recovery' do
      expect(fox.send(:recovery_due?)).to be true
    end

    context 'when consumer cancel fails because the channel is already closed' do
      before do
        allow(consumer).to receive(:cancel).and_raise(Timeout::Error.new('closed channel'))
      end

      it 'does not raise' do
        expect { fox.pause! }.not_to raise_error
      end

      it 'is paused' do
        expect(fox).to be_paused
      end
    end
  end

  # Process is triggered via the subscription.
  describe '#process' do
    let(:message) do
      msg = instance_spy(Warren::Subscriber::Base)
      allow(msg).to receive(:payload).and_return('test_payload')
      msg
    end

    before do
      delivery_info = instance_double('Bunny::DeliveryInfo', delivery_tag: 'delivery_tag')
      allow(subscription).to receive(:subscribe).and_return(consumer).and_yield(delivery_info, 'y', 'test_payload')
      allow(adaptor).to receive(:handle).and_yield
      allow(Warren::Subscriber::Base).to receive(:new).with(fox, delivery_info, 'y', 'test_payload').and_return(message)
    end

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

      it 'does not raise if requeue fails on a closed channel' do
        allow(adaptor).to receive(:handle).and_raise(Warren::Exceptions::TemporaryIssue)
        allow(message).to receive(:requeue).and_raise(Timeout::Error.new('closed channel'))

        expect { fox.run! }.not_to raise_error
      end

      it 'does not raise if dead-letter fails on a closed channel' do
        allow(message).to receive(:_process_).and_raise(NameError, 'message error')
        allow(message).to receive(:dead_letter).and_raise(Timeout::Error.new('closed channel'))

        expect { fox.run! }.not_to raise_error
      end

      it 'pauses the fox if dead-letter fails on a closed channel' do
        allow(message).to receive(:_process_).and_raise(NameError, 'message error')
        allow(message).to receive(:dead_letter).and_raise(Timeout::Error.new('closed channel'))

        fox.run!
        expect(fox).to be_paused
      end

      it 'tracks the message as pending dead-letter when dead-letter fails on a closed channel' do
        allow(message).to receive(:_process_).and_raise(NameError, 'message error')
        allow(message).to receive(:dead_letter).and_raise(Timeout::Error.new('closed channel'))

        fox.run!
        # The message should be in pending set
        expect(fox.instance_variable_get(:@pending_dead_letter_messages)).not_to be_empty
      end

      it 'forces dead-letter when a pending message is re-delivered' do
        message_id = Digest::SHA256.hexdigest('test_payload')
        fox.instance_variable_get(:@pending_dead_letter_messages).add(message_id)

        fox.run!

        expect(message).to have_received(:dead_letter).with(instance_of(StandardError))
      end

      it 'removes pending marker after successful dead-letter on redelivery' do
        message_id = Digest::SHA256.hexdigest('test_payload')
        fox.instance_variable_get(:@pending_dead_letter_messages).add(message_id)

        fox.run!

        expect(fox.instance_variable_get(:@pending_dead_letter_messages)).not_to include(message_id)
      end

      it 'does not clear pending dead-letter messages when recovery completes' do
        allow(adaptor).to receive(:recovered?).and_return(true)
        allow(subscription).to receive(:subscribe).and_return(consumer)
        recover_with_pending_dead_letter('test_payload')

        expect(pending_dead_letter_messages).to include(message_id('test_payload'))
      end
    end
  end

  def message_id(payload)
    Digest::SHA256.hexdigest(payload)
  end

  def pending_dead_letter_messages
    fox.instance_variable_get(:@pending_dead_letter_messages)
  end

  def recover_with_pending_dead_letter(payload)
    fox.run!
    fox.pause!
    pending_dead_letter_messages.add(message_id(payload))
    fox.attempt_recovery
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

      it 'reopens the subscription once recovered' do
        allow(adaptor).to receive(:recovered?).and_return(true)

        fox.attempt_recovery

        expect(subscription).to have_received(:reopen!)
      end

      it 'reopens delayed exchange on the subscription channel once recovered' do
        allow(adaptor).to receive(:recovered?).and_return(true)

        fox.attempt_recovery

        expect(delayed).to have_received(:reopen!).with(channel: subscription.channel)
      end

      it 'reactivates the subscription once recovered' do
        allow(adaptor).to receive(:recovered?).and_return(true)

        fox.attempt_recovery

        expect(subscription).to have_received(:activate!).twice
      end

      it 'reactivates the delayed exchange once recovered' do
        allow(adaptor).to receive(:recovered?).and_return(true)

        fox.attempt_recovery

        expect(delayed).to have_received(:activate!).twice
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
