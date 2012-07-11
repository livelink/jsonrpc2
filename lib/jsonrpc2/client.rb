require 'httpclient'
require 'json'

module JSONRPC2
class Error < RuntimeError
end

class Client
  # URI for JSON RPC endpoint
  def initialize(uri)
		@uri = uri
		@client = HTTPClient.new
		@id = 0
	end

  # Call method with named arguments
	def call(method, args = {}, options = {}, &block)
		headers = { 'Content-Type' => 'application/json-rpc' }
    if options[:headers]
      headers = headers.merge(options[:headers])
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
				raise Error, data['error']['message']
			end
		else
			raise result.body
		end
	end
end
end
