# frozen_string_literal: true

require 'rack'
require 'digest'
require 'jsonrpc2'
require 'jsonrpc2/accept'
require 'jsonrpc2/textile'
require 'jsonrpc2/auth'
require 'jsonrpc2/html'
require 'jsonrpc2/types'
require 'json'
require 'base64'

module JSONRPC2
  module_function

  def environment
    ENV['RACK_ENV'] || ENV['RAILS_ENV'] || 'development'
  end

  def development?
    environment.eql?('development')
  end

  # Authentication failed error - only used if transport level authentication isn't.
  # e.g. BasicAuth returns a 401 HTTP response, rather than throw this.
  class AuthFail < RuntimeError; end

  # API error - thrown when an error is detected, e.g. params of wrong type.
  class APIFail < RuntimeError; end

  # KnownError - thrown when a predictable error occurs.
  class KnownError < RuntimeError
    attr_accessor :code, :data
    def self.exception(args)
      code, message, data = *args
      exception = new(message)
      exception.code = code
      exception.data = data
      exception
    end
  end

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
          environment['json.request-id'] = Digest::MD5.hexdigest("#{$host ||= Socket.gethostname}-#{$$}-#{Time.now.to_f}")[0,8]
          request = Rack::Request.new(environment)
          catch :rack_response do
            best = JSONRPC2::HTTPUtils.which(environment['HTTP_ACCEPT'], %w[text/html application/json-rpc application/json])

            if request.path_info =~ %r'/_assets' or request.path_info == '/favicon.ico'
              best = 'text/html' # hack for assets
            end

            case best
            when 'text/html', 'text/css', 'image/png' # Assume browser
              monitor_time(environment, request.POST['__json__']) { JSONRPC2::HTML.call(self, request) }
            when 'application/json-rpc', 'application/json', nil # Assume correct by default
              environment['rack.input'].rewind
              raw = environment['rack.input'].read
              data = JSON.parse(raw) if raw.to_s.size >= 2
              monitor_time(environment, raw) { self.new(environment).rack_dispatch(data) }
            else
              [406, {'Content-Type' => 'text/html'},
                ["<!DOCTYPE html><html><head><title>Media type mismatch</title></head><body>I am unable to acquiesce to your request</body></html>"]]
            end
          end

        rescue Exception => e
          if environment['rack.logger'].respond_to?(:error)
            environment['rack.logger'].error "#{e.class}: #{e.message} - #{e.backtrace * "\n    "}"
          end
          raise e.class, e.message, e.backtrace
        end

        private

        def monitor_time(env, data, &block)
          if env['rack.logger'].respond_to?(:info)
            if env["HTTP_AUTHORIZATION"].to_s =~ /Basic /i
              auth = Base64.decode64(env["HTTP_AUTHORIZATION"].to_s.sub(/Basic /i, '')) rescue nil
              auth ||= env["HTTP_AUTHORIZATION"]
            else
              auth = env["HTTP_AUTHORIZATION"]
            end
            env['rack.logger'].info("[JSON-RPC2] #{env['json.request-id']} #{env['REQUEST_URI']} - Auth: #{auth}, Data: #{data.is_a?(String) ? data : data.inspect}")
          end
          t = Time.now.to_f
          return yield
        ensure
          if env['rack.logger'].respond_to?(:info)
            env['rack.logger'].info("[JSON-RPC2] #{env['json.request-id']} Completed in #{'%.3f' % ((Time.now.to_f - t) * 1000)}ms#{ $! ? " - exception = #{$!.class}:#{$!.message}" : "" }")
          end
        end
      # @!endgroup
    end

    # Create new interface object
    #
    # @param [Hash] env Rack environment
    def initialize(env)
      @_jsonrpc_env = env
      @_jsonrpc_request = Rack::Request.new(env)
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
      result = case rpc_data
      when Array
        rpc_data.map { |rpc| dispatch_single(rpc) }
      else
        dispatch_single(rpc_data)
      end

      return result.to_json
    end

    protected

    # JSON result helper
    def response_ok(id, result)
      { 'jsonrpc' => '2.0', 'result' => result, 'id' => id }
    end

    # JSON error helper
    def response_error(code, message, data)
      { 'jsonrpc' => '2.0', 'error' => { 'code' => code, 'message' => message, 'data' => data }, 'id' => (@_jsonrpc_call && @_jsonrpc_call['id'] || nil) }
    end

    # Params helper
    def params
      @_jsonrpc_call['params']
    end

    # Auth info
    def auth
      @_jsonrpc_auth
    end

    # Rack::Request
    def request
      @_jsonrpc_request
    end

    def env
      @_jsonrpc_env
    end

    # Logger
    def logger
      @_jsonrpc_logger ||= (@_jsonrpc_env['rack.logger'] || Rack::NullLogger.new("null"))
    end

    # Check call validity and authentication & make a single method call
    #
    # @param [Hash] rpc JSON-RPC-2 call
    def dispatch_single(rpc)
      t = Time.now.to_f

      result = _dispatch_single(rpc)

      if result['result']
        logger.info("[JSON-RPC2] #{env['json.request-id']} Call completed OK in #{'%.3f' % ((Time.now.to_f - t) * 1000)}ms")
      elsif result['error']
        logger.info("[JSON-RPC2] #{env['json.request-id']} Call to ##{rpc['method']} failed in #{'%.3f' % ((Time.now.to_f - t) * 1000)}ms with error #{result['error']['code']} - #{result['error']['message']}")
      end

      result
    end

    def _dispatch_single(rpc)
      t = Time.now.to_f
      unless rpc.has_key?('id') && rpc.has_key?('method') && rpc['jsonrpc'].eql?('2.0')
        return response_error(-32600, 'Invalid request', nil)
      end
      @_jsonrpc_call = rpc

      begin
        if self.class.auth_with && ! @_jsonrpc_auth
          (@_jsonrpc_auth = self.class.auth_with.client_check(@_jsonrpc_env, rpc)) or raise AuthFail, "Invalid credentials"
        end

        call(rpc['method'], rpc['id'], rpc['params'])
      rescue AuthFail => e
        response_error(-32000, "AuthFail: #{e.class}: #{e.message}", {}) # XXX: Change me
      rescue APIFail => e
        response_error(-32000, "APIFail: #{e.class}: #{e.message}", {}) # XXX: Change me
      rescue KnownError => e
        response_error(e.code, e.message, e.data) # XXX: Change me
      rescue Exception => e
        logger.error("#{env['json.request-id']} Internal error calling #{rpc.inspect} - #{e.class}: #{e.message} #{e.backtrace.join("\n    ")}") if logger.respond_to?(:error)
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
