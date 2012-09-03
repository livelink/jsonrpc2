require 'httpclient'
require 'json'

module JSONRPC2
# JSON RPC client error
class RemoteError < RuntimeError
end

# JSON RPC remote auth error
class RemoteAuthError < RemoteError
end

# JSON RPC invalid JSON data
class RemoteDataError < RemoteError
end

# JSON RPC wrong content type
class WrongContentTypeError < RemoteError
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

    body = result.body
    body = body.content if body.respond_to?(:content) # Only on old versions of HTTPAccess2 ?

    if result.status_code == 200
      begin
        data = JSON.parse body
      rescue Exception
        body = result.body.to_s
        body = "#{body[0..256]}...[#{body.size-256} bytes trimmed]" if body.size > 256

        if result.contenttype =~ /^application\/json/
          raise RemoteDataError, "Content-Type is '#{result.contenttype}', but body of '#{body}' failed to parse."
        else
          raise WrongContentTypeError, "Content-Type is '#{result.contenttype}', but should be application/json-rpc or application/json (body='#{body}')"
        end
      end

      unless data.is_a?(Hash) && data["jsonrpc"] == "2.0"
        raise RemoteDataError, "No jsonrpc parameter in response.  This must be \"2.0\""
      end

      unless result.contenttype =~ /^application\/json/
        STDERR.puts "WARNING: Content-Type is '#{result.contenttype}', but should be application/json-rpc or application/json."
      end

      if data.has_key?('result')
        return data['result']
      elsif data.has_key?('error')
        if data['error']['code'] == -32000 && data['error']['message'] =~ /^AuthFail/
          raise RemoteAuthError, data['error']['message']
        else
          raise RemoteError, data['error']['message']
        end
      else
        body = result.body.to_s
        body = "#{body[0..256]}...[#{body.size-256} bytes trimmed]" if body.size > 256

        raise RemoteDataError, "A JSON-RPC 2.0 response must either have a 'result' or an 'error' value - in '#{body}'."
      end
    elsif result.status_code == 401
      if result.headers['WWW-Authenticate'].to_s =~ /realm="([^"]*?)"/
        suffix = " for #{$1}"
      end
      raise RemoteAuthError, "Authentication failed#{suffix}"
    else
      raise RemoteAuthError, "Call failed - HTTP status #{result.status_code}"
    end
  end
end
end
