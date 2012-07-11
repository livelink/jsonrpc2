require 'jsonrpc2'
require 'jsonrpc2/accept'
require 'jsonrpc2/textile'
require 'jsonrpc2/html'
require 'json'

module JSONRPC2
  # Your code goes here...
class APIFail < RuntimeError
end
class Interface
	class << self
		def auth_type *args
			if args.empty?
				return @auth_type
			else
				@auth_type = args[0]
				@auth_info = args[1] || {}
			end
		end
		attr_reader :auth_info

    class RackWrap
      def initialize(environment)
        @environment = environment
      end
      #def logger
      #  @environment['rack.logger']
      #end
      def request
        self
      end
      def env
        self
      end
      def [](key)
        @environment[key]
      end
    end

    def call(environment)
      request = Rack::Request.new(environment)
      case JSONRPC2.which(environment['HTTP_ACCEPT'], %w[text/html application/jsonrpc application/json])
      when 'text/html', nil
        JSONRPC2::HTML.call(self, request)
      when 'application/jsonrpc', 'application/json'
        environment['rack.input'].rewind
        data = JSON.parse(environment['rack.input'].read)
        [200, {'Content-Type' => 'application/json-rpc'}, self.new(RackWrap.new(environment)).dispatch(data)]
      else
        [406, {'Content-Type' => 'text/html'}, "No"]
      end
    end
	end
	def initialize(env, options = {})
		@env = env
	end
	def dispatch(rpcData)
		if rpcData.is_a?(Array)
			rpcData.map { |rpc|
				_dispatch_single(rpc)
			}.to_json
		else
			_dispatch_single(rpcData).to_json
		end
	end
	def auth_type
		self.class.auth_type()
	end

	protected
	def auth_info
		self.class.auth_info
	end
	def response_ok(id, result)
		{ 'jsonrpc' => '2.0', 'result' => result, 'id' => id }
	end
	def response_error(code, message, data)
		{ 'jsonrpc' => '2.0', 'error' => { 'code' => code, 'message' => message, 'data' => data }, 'id' => @id }
	end
	def auth_basic!
		begin
			if auth = @env['HTTP_AUTHORIZATION']
        m = /Basic\s+([A-Za-z0-9+\/]+=*)/.match(auth)
				key = auth_info[:secret]+"/"+Time.now.strftime('%Y-%m-%d')
				src = GibberishAES.dec(auth, key)
				info = JSON.parse(src)
				throw(:auth_ok)
			else
				return response_error(-32000, "Authentication missing", "")
			end
		rescue Exception => e
			return response_error(-32000, "Authentication failed - #{e.message}/#{e.class}", "")
		end
	end

	def _dispatch_single(rpc)
		unless rpc.has_key?('id') && rpc.has_key?('method') && rpc['jsonrpc'].eql?('2.0')
			@id = nil
			return response_error(-32600, 'Invalid request', nil)
		end
		@id = rpc['id']
		@method = rpc['method']
		@rpc = rpc


		if respond_to?(s="auth_#{auth_type}!")
			catch(:auth_ok) do
				r = __send__(s)
				return r
			end
		end
				
		begin
			call(rpc['method'], rpc['id'], rpc['params'])
		rescue APIFail => e
			response_error(-32000, "#{e.class}: #{e.message}", {}) # XXX: Change me
		rescue Exception => e
			response_error(-32000, "#{e.class}: #{e.message}", e.backtrace) # XXX: Change me
		end
	end
	def call(method, id, params)
		if public_methods(false).map(&:to_s).include?(method)
			begin
				JsonRpcType.valid_params?(self.class, method, params)
			rescue Exception => e
				return response_error(-32602, "Invalid params - #{e.message}", {})
			end

      if self.method(method).arity.zero?
  			result = send(method)
      else
	  		result = send(method, params)
      end

			begin
				JsonRpcType.valid_result?(self.class, method, result)
			rescue Exception => e
				return response_error(-32602, "Invalid result - #{e.message}", {})
			end
				
			response_ok(id, result)
		else
			response_error(-32601, "Unknown method `#{method.inspect}'", {})
		end
	end

	module JsonRpcType
		module_function
		def valid?(interface, type, object)
				res = case type
				when 'String'
					object.is_a?(String)
				when 'Number'
					object.kind_of?(Numeric)
				when 'true'
					object == true
				when 'false'
					object == false
				when 'Boolean'
					object == true || object == false
				when 'null'
					object.nil?
				when 'Integer'
					object.kind_of?(Numeric) && (object.to_i.to_f == object.to_f)
				when 'Object'
					object.is_a?(Hash)
				when /Array\[(.*)\]/
					object.is_a?(Array) && object.all? { |value| valid?(interface, $1, value) }
				else # Custom type
					subset = (type[-1] == ?*)
					type = type[0...-1] if subset

					custom = interface.types[type]
					#STDERR.puts "Type Info: #{custom.inspect}"
					if custom
						custom.valid_object?(interface, object, subset)
					else
						raise "Invalid/unknown type: #{type} for #{interface.name}"
					end
				end
				#STDERR.puts "#{interface.name}: #{type} - #{object.inspect} - #{res ? "OK" : "FAIL"}"
				res
		end
		def valid_params?(interface, method, data)
			about = interface.about[method.to_s.intern]
			return true if about.nil? # Undefined

			params = (about[:params] || [])
			param_names = params.map { |param| param[:name] }

			if params.empty? && data.empty?
				return true
			end

			extra_keys = data.keys - param_names
			unless extra_keys.empty?
				raise "Extra parameters #{extra_keys.inspect} for #{method}."
			end
			
			params.all? do |param|
				if data.has_key?(param[:name])
					JsonRpcType.valid?(interface, param[:type], data[param[:name].to_s])
				elsif ! param[:required]
					next true
				else
					raise "Missing parameter: '#{param[:name]}' of type #{param[:type]} for #{method}"
				end
			end
		end
		def valid_result?(interface, method, data)
			about = interface.about[method.to_s.intern]
			return true if about.nil? # Undefined
			if about[:returns].nil?
				return data.nil?
			end
			JsonRpcType.valid?(interface, about[:returns][:type], data)
		end
	end

	class JsonObjectType
		attr_accessor :name, :fields
		def initialize(name, fields)
			@name, @fields = name, fields
			@required = true
		end
		def valid_object?(interface, object, subset = false)
			object.keys.all? { |key| fields.any? { |field| field[:name] == key } } &&
				fields.all? { |field| (object.keys.include?(field[:name]) &&
					JsonRpcType.valid?(interface, field[:type], object[field[:name]])) || subset || (! field[:required]) }
		end

		def field(name, type, desc)
			@fields << { :name => name, :type => type, :desc => desc, :required => @required }
		end
		def string name, desc; field(name, 'String', desc); end
		def number name, desc; field(name, 'Number', desc); end
		def integer name, desc; field(name, 'Integer', desc); end
		def boolean name, desc; field(name, 'Boolean', desc); end

		def optional(&block)
			old_required = @required
			begin
				@required = false
				yield(self)
			ensure
				@required = old_required
			end
		end
		def required(&block)
			old_required = @required
			begin
				@required = true
				yield(self)
			ensure
				@required = old_required
			end
		end

	end

	class << self
		def ___append_param name, type, options
			@params ||= []
			unless options.has_key?(:required)
				options[:required] = true
			end
			@params << options.merge({ :name => name, :type => type })
		end

		def param name, type, desc = nil, options = nil
			if options.nil? && desc.is_a?(Hash)
				options, desc = desc, nil
			end
			options ||= {}
			options[:desc] = desc if desc.is_a?(String)
			
			___append_param name, type, options
		end

		def optional name, type, desc = nil, options = nil
			if options.nil? && desc.is_a?(Hash)
				options, desc = desc, nil
			end
			options ||= {}
			options[:desc] = desc if desc.is_a?(String)

			___append_param(name, type, nil, options.merge(:required => false))
		end

		def result type, desc = nil
			@result = { :type => type, :desc => desc }
		end

		def desc str
			@desc = str
		end

		def example desc, code
			@examples ||= []
			@examples << { :desc => desc, :code => code }
		end

		def type name, *fields
			@types ||= {}
			type = JsonObjectType.new(name, fields)

			if block_given?
				yield(type)
			end

			@types[name] = type
		end

		def section name, summary=nil
			@sections ||= []
			@sections << {:name => name, :summary => summary}

			@current_section = name
			if block_given?
				yield
				@current_section = nil
			end
		end
		def nodoc
			@nodoc = true
		end

		def title str = nil
			@title = str if str
		end

		def introduction str = nil
			@introduction = str if str
		end

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
		attr_reader :about, :types

    include JSONRPC2::TextileEmitter
	end
end
end
