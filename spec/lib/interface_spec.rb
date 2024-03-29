# frozen_string_literal: true

require 'json'
require 'base64'
require 'logger'
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
        return 42 if params['name'] == 'Marvin'

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
      let(:rpc_request_data) { super().merge('params' => params) }
      let(:params) { { 'name' => 'Geoff' } }

      it 'returns the valid response' do
        expect(parsed_response_body[:result]).to eq('Hello, Geoff!')
      end

      context 'with an extra param' do
        let(:params) { super().merge('extra' => 'I should not be here') }

        it 'returns the helpful param error' do
          expect(parsed_response_body[:error]).to eq(
            code: -32602,
            message: 'Invalid params - Extra parameters ["extra"] for hello.',
            data: {}
          )
        end
      end

      context 'with an invalid result type' do
        let(:params) { { 'name' => 'Marvin' } }

        it 'informs about the server error' do
          expect(parsed_response_body[:error]).to match(
            code: -32000,
            message: 'An error occurred. Check logs for details',
            data: {}
          )
        end
      end

      context 'with a correctly configured before_validation hook' do
        before do
          rpc_api_class.class_eval do
            attr_reader :test_before_validation_data

            def before_validation(method:, id:, params:)
              @test_before_validation_data = {
                method: method,
                id: id,
                params: params
              }
            end
          end
        end

        it 'invokes the hook' do
          dispatch_result

          expect(instance.test_before_validation_data[:method]).to eq('hello')
          expect(instance.test_before_validation_data[:id]).to eq(123)
          expect(instance.test_before_validation_data[:params]).to eq({ 'name' => 'Geoff' })
        end
      end
    end

    context 'with an unhandled server error' do
      let(:rpc_request_data) { super().merge('params' => { 'name' => 'Voldemort' }) }

      it 'informs about the server error' do
        expect(parsed_response_body[:error]).to match(
          code: -32000,
          message: 'An error occurred. Check logs for details',
          data: {}
        )
      end

      context 'with a correctly configured error hook' do
        before do
          rpc_api_class.class_eval do
            attr_reader :test_error_data

            def on_server_error(request_id:, error:)
              @test_error_data = {
                request_id: request_id,
                error: error
              }
            end
          end
        end

        it 'invokes the hook' do
          dispatch_result

          expect(instance.test_error_data[:error].message).to eq('He-Must-Not-Be-Named')
          expect(instance.test_error_data[:request_id]).to eq(nil) # Request_id is generated higher in the stack
        end
      end

      context 'with error hook raising an error' do
        let(:initialization_params) { super().merge('rack.logger' => rack_logger) }
        let(:rack_logger) { instance_double(::Logger, :rack_logger, info: nil, error: nil) }

        before do
          rpc_api_class.class_eval do
            def on_server_error(request_id:, error:)
              raise "Whoops, my bad!"
            end
          end
        end

        it 'informs about the server error' do
          expect(parsed_response_body[:error]).to match(
            code: -32000,
            message: 'An error occurred. Check logs for details',
            data: {}
          )
        end

        it 'logs the error' do
          expect(rack_logger).to receive(:error).with(/Whoops, my bad!/)

          dispatch_result
        end
      end
    end
  end
end
