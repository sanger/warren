# frozen_string_literal: true

require 'spec_helper'
require 'warren/app/config'
require 'yaml'

RSpec.describe Warren::App::Config do
  describe '::invoke' do
    subject(:invocation) { described_class.invoke(shell, path: path, exchange: 'exchange') }

    let(:shell) { instance_double(Thor::Shell::Basic) }
    let(:path) { 'tmp/test.yml' }
    let(:file) { instance_double(File, write: 20) }

    let(:expected_payload) do
      parsed_yaml = {
        'development' => {
          'type' => 'log',
          'config' => {
            'server' => {
              'host' => 'localhost',
              'port' => 5672,
              'username' => 'guest',
              'password' => 'guest',
              'vhost' => '/',
              'frame_max' => 0,
              'heartbeat' => 30
            },
            'exchange' => 'exchange'
          }
        },
        'test' => { 'type' => 'test' }
      }
      # We're inlining comments, but are mostly concerned with the yaml
      # content. This ensures that the data map to what we expect
      satisfy('a valid yaml file') { |v| YAML.safe_load(v) == parsed_yaml }
    end

    before do
      allow(File).to receive(:exist?).and_return(exist)
      allow(File).to receive(:open).with(path, 'w').and_yield(file)
    end

    context 'with a new file and complete configuration' do
      let(:exist) { false }

      it 'creates a new config' do
        invocation
        expect(file).to have_received(:write).with(expected_payload)
      end
    end

    context 'with an existing file and complete configuration' do
      before do
        allow(shell).to receive(:yes?).with("#{path} exists. Overwrite (Y/N)? ").and_return(true)
      end

      let(:exist) { true }

      it 'prompts the user to overwrite' do
        invocation
        expect(shell).to have_received(:yes?)
      end

      it 'creates a new config' do
        invocation
        expect(file).to have_received(:write).with(expected_payload)
      end
    end

    context 'with an existing file which is aborted' do
      before do
        allow(shell).to receive(:yes?).with("#{path} exists. Overwrite (Y/N)? ").and_return(false)
      end

      let(:exist) { true }

      it 'prompts the user to overwrite' do
        invocation
        expect(shell).to have_received(:yes?)
      end

      it 'does not create a new config' do
        invocation
        expect(File).not_to have_received(:open)
      end
    end

    context 'with no exchange' do
      subject(:invocation) { described_class.invoke(shell, path: path, exchange: nil) }

      before do
        allow(shell).to receive(:ask).with('Specify an exchange: ').and_return('exchange')
      end

      let(:exist) { false }

      it 'prompts the user for an exchange' do
        invocation
        expect(shell).to have_received(:ask)
      end

      it 'creates a new config' do
        invocation
        expect(file).to have_received(:write).with(expected_payload)
      end
    end
  end
end
