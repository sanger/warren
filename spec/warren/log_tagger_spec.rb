# frozen_string_literal: true

require 'spec_helper'
require 'warren/log_tagger'
require 'logger'

RSpec.describe Warren::LogTagger do
  subject(:logger) { described_class.new(logger: standard_logger, tag: 'tag') }

  let(:standard_logger) { instance_double(Logger) }

  before do
    allow(standard_logger).to receive(:debug) { |&block| block&.call }
    allow(standard_logger).to receive(:info) { |&block| block&.call }
    allow(standard_logger).to receive(:warn) { |&block| block&.call }
    allow(standard_logger).to receive(:error) { |&block| block&.call }
  end

  shared_examples 'a logger' do |method|
    context 'without a block' do
      before { logger.send(method, 'message') }

      it 'tags the message' do
        expect(standard_logger).to have_received(method).with('tag: message')
      end
    end

    context 'with a block' do
      subject(:method_call) { logger.send(method, 'program') { 'message' } }

      it 'calls the logger as normal' do
        method_call
        expect(standard_logger).to have_received(method).with('program')
      end

      it { is_expected.to eq 'tag: message' }
    end
  end

  describe '#debug' do
    it_behaves_like 'a logger', :debug
  end

  describe '#info' do
    it_behaves_like 'a logger', :info
  end

  describe '#error' do
    it_behaves_like 'a logger', :error
  end

  describe '#warn' do
    it_behaves_like 'a logger', :warn
  end
end
