# frozen_string_literal: true

require 'spec_helper'
require 'warren/handler'

RSpec.describe Warren::Handler do
  describe '::routing_key_template' do
    let(:routing_key) { 'example.key' }
    let(:template) { described_class.routing_key_template(routing_key_prefix) }

    context 'when nil' do
      let(:routing_key_prefix) { nil }
      it 'returns a template without a prefix' do
        expect(template % routing_key).to eq(routing_key)
      end
    end

    context 'when provided' do
      let(:routing_key_prefix) { 'test' }
      it 'returns a template with a prefix' do
        expect(template % routing_key).to eq("#{routing_key_prefix}.#{routing_key}")
      end
    end
  end
end
