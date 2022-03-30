# frozen_string_literal: true

require 'json'
require 'base64'
require 'jsonrpc2/interface'
require 'jsonrpc2/auth'

RSpec.describe JSONRPC2::Interface do
  let(:instance) { rpc_api_class.new(initialization_params) }
  let(:basic_auth_credentials) { 'user:valid_password' }
  let(:initialization_params) { { 'HTTP_AUTHORIZATION' => "Basic #{Base64.encode64(basic_auth_credentials)}" } }
  let(:rpc_api_class) do
    Class.new(described_class) do
      auth_with JSONRPC2::BasicAuth.new('user' => 'valid_password')

      param 'name', 'String', 'name'
      result 'String', 'A tailored greeting'
      def hello
        raise 'He-Must-Not-Be-Named' if params['name'] == 'Voldemort'
        "Hello, #{params['name']}!"
      end
    end
  end

  describe '#rack_dispatch' do
    subject(:dispatch_result) { instance.rack_dispatch(rpc_request_data) }

    let(:rpc_request_data) { { 'id' => 123, 'method' => 'hello', 'jsonrpc' => '2.0' } }
    let(:response_status) { dispatch_result[0] }
    let(:response_body) { dispatch_result[2][0] }
    let(:parsed_response_body) { JSON.parse(response_body, symbolize_names: true) }

    context 'with empty input' do
      let(:rpc_request_data) { {} }

      it 'returns the "Invalid request" error' do
        expect(parsed_response_body[:error]).to eq(
          code: -32600,
          message: 'Invalid request',
          data: nil
        )
      end
    end

    context 'with invalid credentials' do
      let(:basic_auth_credentials) { 'user:invalid_password' }
      it 'returns the authorization error' do
        expect(response_status).to eq(401)
        expect(response_body).to include('Authentication Required')
      end
    end

    context 'with no params' do
      it 'returns the "Params should not be nil" error' do
        expect(parsed_response_body[:error]).to eq(
          code: -32602,
          message: 'Invalid params - Params should not be nil',
          data: {}
        )
      end
    end

    context 'with a missing param' do
      let(:rpc_request_data) { super().merge('params' => {}) }

      it 'returns a helpful param error' do
        expect(parsed_response_body[:error]).to eq(
          code: -32602,
          message: 'Invalid params - Missing parameter: \'name\' of type String for hello',
          data: {}
        )
      end
    end

    context 'with a mismatched type of param' do
      let(:rpc_request_data) { super().merge('params' => { 'name' => true }) }

      it 'returns the helpful param error' do
        expect(parsed_response_body[:error]).to eq(
          code: -32602,
          message: 'Invalid params - \'name\' should be of type String, was TrueClass',
          data: {}
        )
      end
    end

    context 'with a valid param' do
      let(:rpc_request_data) { super().merge('params' => { 'name' => 'Geoff' }) }

      it 'returns the valid response' do
        expect(parsed_response_body[:result]).to eq('Hello, Geoff!')
      end
    end

    context 'with an unhandled server error' do
      let(:rpc_request_data) { super().merge('params' => { 'name' => 'Voldemort' }) }

      it 'informs about the server error' do
        expect(parsed_response_body[:error]).to match(
          code: -32000,
          message: 'RuntimeError: He-Must-Not-Be-Named', # Bad - exposes class and private error message
          data: a_kind_of(Array)                         # Bad - exposes stacktrace
        )
      end
    end
  end
end
