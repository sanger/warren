# frozen_string_literal: true

require 'spec_helper'
require 'warren/app/consumer'
require 'warren/app/consumer_add'

RSpec.describe Warren::App::Consumer do
  let(:default_path) { 'config/warren_consumers.yml' }
  let(:a_thor_shell) { a_kind_of(described_class) }

  describe '#add' do
    let(:action) { 'add' }

    before do
      allow(Warren::App::ConsumerAdd).to receive(:invoke)
      described_class.start([action, *arguments])
    end

    context 'without arguments' do
      let(:arguments) { [] }

      it 'invokes Warren::App:Consumer with default arguments' do
        expect(Warren::App::ConsumerAdd).to have_received(:invoke)
          .with(a_thor_shell, nil, { path: default_path })
      end
    end

    context 'with arguments' do
      let(:arguments) do
        ['consumer_name', '--path=tmp/path', '--desc=my_exchange', '--queue=queue_name', '--bindings=a', 'b', 'c']
      end

      it 'invokes Warren::App:Config with supplied arguments' do
        expect(Warren::App::ConsumerAdd).to have_received(:invoke)
          .with(a_thor_shell, 'consumer_name',
                { queue: 'queue_name', bindings: %w[a b c],
                  path: 'tmp/path', desc: 'my_exchange' })
      end
    end
  end
end
