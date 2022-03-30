# frozen_string_literal: true

require 'json'
require 'jsonrpc2/interface'

RSpec.describe JSONRPC2::Interface do
  let(:instance) { described_class.new({}) }

  describe '#dispatch' do
    subject(:dispatch_result) { instance.dispatch(rpc_data) }

    let(:rpc_data) { {} }
    let(:parsed_dispatch_result) { JSON.parse(dispatch_result, symbolize_names: true) }

    context 'with empty input' do
      it 'returns the "Invalid request" error' do
        expect(parsed_dispatch_result[:error]).to eq(
          code: -32600,
          message: 'Invalid request',
          data: nil
        )
      end
    end
  end
end
