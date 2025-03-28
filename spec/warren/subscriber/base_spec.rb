# frozen_string_literal: true

require 'spec_helper'
require 'helpers/dummy_active_record'
require 'warren/fox'
require 'warren/subscription'
require 'warren/subscriber/base'

RSpec.describe Warren::Subscriber::Base do
  subject(:subscriber) do
    delivery_info = instance_double('Bunny::DeliveryInfo', delivery_tag: 'delivery_tag', routing_key: 'test.key')
    headers = retry_attempts.zero? ? nil : { 'attempts' => retry_attempts }
    properties = instance_double('Bunny::MessageProperties', headers: headers)
    described_class.new(fox, delivery_info, properties, 'Hello')
  end

  before do
    allow(subscription).to receive(:ack)
    allow(subscription).to receive(:nack)
  end

  let(:subscription) { instance_spy(Warren::Subscription, 'subscription') }
  let(:delayed) { instance_spy(Warren::DelayExchange, 'delayed') }

  let(:retry_attempts) { 0 }
  let(:fox) { instance_spy(Warren::Fox, subscription: subscription, error: nil, warn: nil, delayed: delayed) }

  describe '#process' do
    it 'acknowledges the message' do
      subscriber._process_
      expect(subscription).to have_received(:ack).with('delivery_tag')
    end

    it 'raises Warren::MultipleAcknowledgements if both acked and nacked' do
      subscriber.dead_letter(StandardError.new('I do not like it'))

      expect { subscriber.send(:ack) }.to raise_error(Warren::Exceptions::MultipleAcknowledgements)
    end
  end

  describe '#requeue' do
    before { subscriber.requeue(StandardError.new('Not working')) }

    it 'sends a nack to requeue a single message' do
      expect(subscription).to have_received(:nack).with('delivery_tag', false, true)
    end

    it 'logs the issue', aggregate_failures: true do
      expect(fox).to have_received(:warn).with('Re-queue: Hello')
      expect(fox).to have_received(:warn).with('Re-queue Exception: Not working')
    end
  end

  describe '#dead_letter' do
    before { subscriber.dead_letter(StandardError.new('Not working')) }

    it 'sends a nack to reject a message' do
      expect(subscription).to have_received(:nack).with('delivery_tag')
    end

    it 'logs the issue', aggregate_failures: true do
      expect(fox).to have_received(:error).with('Dead-letter: Hello')
      expect(fox).to have_received(:error).with('Dead-letter Exception: Not working')
    end
  end

  describe '#delay' do
    before { subscriber.delay(StandardError.new('Not working')) }

    context 'with no attempts' do
      let(:retry_attempts) { 0 }

      it 'acks the original message' do
        expect(subscription).to have_received(:ack).with('delivery_tag')
      end

      it 'posts the message to the delay exchange' do
        expect(delayed).to have_received(:publish).with('Hello', routing_key: 'test.key', headers: { attempts: 1 })
      end

      it 'logs the issue', aggregate_failures: true do
        expect(fox).to have_received(:warn).with('Delay: Hello')
        expect(fox).to have_received(:warn).with('Delay Exception: Not working')
      end
    end

    context 'with multiple attempts' do
      let(:retry_attempts) { 500 }

      it 'sends a nack to reject a message' do
        expect(subscription).to have_received(:nack).with('delivery_tag')
      end

      it 'does not post the message to the delay exchange' do
        expect(delayed).not_to have_received(:publish)
      end

      it 'logs the issue', aggregate_failures: true do
        expect(fox).to have_received(:error).with('Dead-letter: Hello')
        expect(fox).to have_received(:error).with('Dead-letter Exception: Not working')
      end
    end
  end
end
