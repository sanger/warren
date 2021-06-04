# frozen_string_literal: true

require 'spec_helper'
require 'warren/app/cli'

RSpec.describe Warren::App::Cli do
  subject(:command) { described_class.start([action, *arguments]) }

  let(:default_path) { 'config/warren.yml' }
  let(:a_thor_shell) { a_kind_of(described_class) }

  describe '#config' do
    let(:action) { 'config' }

    before do
      allow(Warren::App::Config).to receive(:invoke)
    end

    context 'without arguments' do
      let(:arguments) { [] }

      it 'invokes Warren::App:Config with default arguments' do
        command
        expect(Warren::App::Config).to have_received(:invoke)
          .with(a_thor_shell, path: default_path, exchange: nil)
      end
    end

    context 'with arguments' do
      let(:arguments) { ['--path=tmp/path', '--exchange=my_exchange'] }

      it 'invokes Warren::App:Config with supplied arguments' do
        command
        expect(Warren::App::Config).to have_received(:invoke)
          .with(a_thor_shell, path: 'tmp/path', exchange: 'my_exchange')
      end
    end
  end
end
