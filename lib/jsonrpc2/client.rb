require 'httpclient'
require 'json'

module JSONRPC2
# JSON RPC client error
class RemoteError < RuntimeError
end

# JSON RPC remote auth error
class RemoteAuthError < RemoteError
end

# Simple JSONRPC client
class Client
  # Create client object
  #
  # @param [String] uri Create client object
  # @param [Hash] options Global options
  def initialize(uri, options = {})
		@uri = uri
		@client = HTTPClient.new
    @options = options
		@id = 0
	end

  # Call method with named arguments
  # @param [String] method Remote method name
  # @param [Hash<String,Value>] args Hash of named arguments for function
  # @param [Hash<String,String>] options Additional parameters
  # @return Method call result
  # @raise [RemoteError] Error thrown by API
  # @raise Transport/Network/HTTP errors
	def call(method, args = {}, options = {}, &block)
		headers = { 'Content-Type' => 'application/json-rpc' }

    # Merge one level of hashes - ie. merge :headers
    options = @options.merge(options) { |key,v1,v2| v2 = v1.merge(v2) if v1.class == v2.class && v1.is_a?(Hash); v2 }

    if options[:headers]
      headers = headers.merge(options[:headers])
    end

    if options[:user] && options[:pass]
      @client.set_auth(@uri, options[:user], options[:pass])
    end
		result = @client.post(@uri, 
							  { 'method' => method, 'params' => args, 'jsonrpc' => '2.0', 'id' => (@id+=1) }.to_json,
							  headers)
		if result.contenttype =~ /^application\/json/
			body = result.body
			body = body.content if body.respond_to?(:content) #
			data = JSON.parse body
			if data.has_key?('result')
				return data['result']
			else
        if data['error']['code'] == -32000 && data['error']['message'] =~ /^AuthFail/
          raise RemoteAuthError, data['error']['message']
        else
          raise RemoteError, data['error']['message']
        end
			end
    elsif result.status_code == 401
      if result.headers['WWW-Authenticate'].to_s =~ /realm="([^"]*?)"/
        suffix = " for #{$1}"
      end
      raise RemoteAuthError, "Authentication failed#{suffix}"
		else
			raise result.body
		end
	end
end
end
