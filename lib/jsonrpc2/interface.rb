require 'jsonrpc2'
require 'jsonrpc2/accept'
require 'jsonrpc2/textile'
require 'jsonrpc2/auth'
require 'jsonrpc2/html'
require 'jsonrpc2/types'
require 'json'
require 'base64'

module JSONRPC2
  # Authentication failed error - only used if transport level authentication isn't.
  # e.g. BasicAuth returns a 401 HTTP response, rather than throw this.
  class AuthFail < RuntimeError; end

  # API error - thrown when an error is detected, e.g. params of wrong type.
  class APIFail < RuntimeError; end

# Base class for JSONRPC2 interface
class Interface
	class << self

# @!group Authentication

    # Get/set authenticator object for API interface - see {JSONRPC2::Auth} and {JSONRPC2::BasicAuth}
    #
    # @param [#check] args An object that responds to check(environment, json_call_data)
    # @return [#check, nil] Currently set object or nil
		def auth_with *args
			if args.empty?
				return @auth_with
			else
				@auth_with = args[0]
			end
		end

# @!endgroup

# @!group Rack-related

    # Rack compatible call handler
    #
    # @param [Hash] environment Rack environment hash
    # @return [Array<Fixnum, Hash<String,String>, Array<String>>] Rack-compatible response
    def call(environment)
      request = Rack::Request.new(environment)
      catch :rack_response do
        case JSONRPC2::HTTPUtils.which(environment['HTTP_ACCEPT'], %w[text/html application/json-rpc application/json])
        when 'text/html'
          JSONRPC2::HTML.call(self, request)
        when 'application/json-rpc', 'application/json', nil # Assume correct by default
          environment['rack.input'].rewind
          data = JSON.parse(environment['rack.input'].read)
          self.new(environment).rack_dispatch(data)
        else
          [406, {'Content-Type' => 'text/html'}, 
            ["<!DOCTYPE html><html><head><title>Media type mismatch</title></head><body>I am unable to acquiesce to your request</body></html>"]]
        end
      end
    end

# @!endgroup

	end

  # Create new interface object
  #
  # @param [Hash] env Rack environment
	def initialize(env)
		@env = env
	end
  # Internal
  def rack_dispatch(rpcData)
    catch(:rack_response) do
      json = dispatch(rpcData)
      [200, {'Content-Type' => 'application/json-rpc'}, [json]]
    end
  end

  # Dispatch call to api method(s)
  #
  # @param [Hash,Array] rpc_data Array of calls or Hash containing one call
  # @return [Hash,Array] Depends on input, but either a hash result or an array of results corresponding to calls.
  def dispatch(rpc_data)
		case rpc_data
    when Array
			rpc_data.map { |rpc| dispatch_single(rpc) }.to_json
		else
			dispatch_single(rpc_data).to_json
		end
	end

	protected
  # JSON result helper
	def response_ok(id, result)
		{ 'jsonrpc' => '2.0', 'result' => result, 'id' => id }
	end
  # JSON error helper
	def response_error(code, message, data)
		{ 'jsonrpc' => '2.0', 'error' => { 'code' => code, 'message' => message, 'data' => data }, 'id' => @id }
	end
  # Check call validity and authentication & make a single method call
  #
  # @param [Hash] rpc JSON-RPC-2 call
	def dispatch_single(rpc)
		unless rpc.has_key?('id') && rpc.has_key?('method') && rpc['jsonrpc'].eql?('2.0')
			@id = nil
			return response_error(-32600, 'Invalid request', nil)
		end
		@id = rpc['id']
		@method = rpc['method']
		@rpc = rpc
				
		begin
      if self.class.auth_with 
        self.class.auth_with.client_check(@env, rpc) or raise AuthFail, "Invalid credentials"
      end

			call(rpc['method'], rpc['id'], rpc['params'])
		rescue AuthFail => e
			response_error(-32000, "AuthFail: #{e.class}: #{e.message}", {}) # XXX: Change me
	  rescue APIFail => e
			response_error(-32000, "APIFail: #{e.class}: #{e.message}", {}) # XXX: Change me
		rescue Exception => e
			response_error(-32000, "#{e.class}: #{e.message}", e.backtrace) # XXX: Change me
		end
	end
  # List API methods
  #
  # @return [Array] List of api method names
  def api_methods
    public_methods(false).map(&:to_s) - ['rack_dispatch', 'dispatch']
  end

  # Call method, checking param and return types
  #
  # @param [String] method Method name
  # @param [Integer] id Method call ID - for response
  # @param [Hash] params Method parameters
  # @return [Hash] JSON response
	def call(method, id, params)
		if api_methods.include?(method)
			begin
				Types.valid_params?(self.class, method, params)
			rescue Exception => e
				return response_error(-32602, "Invalid params - #{e.message}", {})
			end

      if self.method(method).arity.zero?
  			result = send(method)
      else
	  		result = send(method, params)
      end

			begin
				Types.valid_result?(self.class, method, result)
			rescue Exception => e
				return response_error(-32602, "Invalid result - #{e.message}", {})
			end
				
			response_ok(id, result)
		else
			response_error(-32601, "Unknown method `#{method.inspect}'", {})
		end
	end

	class << self
    # Store parameter in internal hash when building API
		def ___append_param name, type, options
			@params ||= []
			unless options.has_key?(:required)
				options[:required] = true
			end
			@params << options.merge({ :name => name, :type => type })
		end
    private :___append_param

# @!group DSL

    # Define a named parameter of type #type for next method
    #
    # @param [String] name parameter name
    # @param [String] type description of type see {Types}
		def param name, type, desc = nil, options = nil
			if options.nil? && desc.is_a?(Hash)
				options, desc = desc, nil
			end
			options ||= {}
			options[:desc] = desc if desc.is_a?(String)
			
			___append_param name, type, options
		end

    # Define an optional parameter for next method
		def optional name, type, desc = nil, options = nil
			if options.nil? && desc.is_a?(Hash)
				options, desc = desc, nil
			end
			options ||= {}
			options[:desc] = desc if desc.is_a?(String)

			___append_param(name, type, options.merge(:required => false))
		end

    # Define type of return value for next method
		def result type, desc = nil
			@result = { :type => type, :desc => desc }
		end

    # Set description for next method
		def desc str
			@desc = str
		end

    # Add an example for next method
		def example desc, code
			@examples ||= []
			@examples << { :desc => desc, :code => code }
		end

    # Define a custom type
		def type name, *fields
			@types ||= {}
			type = JsonObjectType.new(name, fields)

			if block_given?
				yield(type)
			end

			@types[name] = type
		end

    # Group methods
		def section name, summary=nil
			@sections ||= []
			@sections << {:name => name, :summary => summary}

			@current_section = name
			if block_given?
				yield
				@current_section = nil
			end
		end

    # Exclude next method from documentation
		def nodoc
			@nodoc = true
		end

    # Set interface title
		def title str = nil
			@title = str if str
		end

    # Sets introduction for interface
		def introduction str = nil
			@introduction = str if str
		end

# @!endgroup

    # Catch methods added to class & store documentation
		def method_added(name)
			return if self == JSONRPC2::Interface
			@about ||= {}
			method = {}
			method[:params] = @params if @params
			method[:returns] = @result if @result
			method[:desc] = @desc if @desc
			method[:examples] = @examples if @examples
			
			if method.empty?
				if public_methods(false).include?(name)
					unless @nodoc
						#logger.info("#{name} has no API documentation... :(")
					end
				else
					#logger.debug("#{name} isn't public - so no API")
				end
			else
				method[:name] = name
				method[:section] = @current_section
				method[:index] = @about.size
				@about[name.to_s] = method
			end

			@result = nil
			@params = nil
			@desc = nil
			@examples = nil
			@nodoc = false
		end
    private :method_added
		attr_reader :about, :types

	end

  extend JSONRPC2::TextileEmitter
end
end
