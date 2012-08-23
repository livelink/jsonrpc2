require 'date'

module JSONRPC2
  # Types are checked against textual descriptions of the contents:
  #
  # * String - A string
  # * Number - Any kind of number
  # * Integer - Integer value
  # * Boolean - true or false
  # * true - True value
  # * false - False value
  # * null - nil value
  # * Object - An object
  # * Array - An array
  # * Array [Type] - An array of type Type
  # * Value (or Any or void) - Any value of any type
  # * CustomType - A defined custom object type
	module Types
		module_function
    DateTimeRegex = %r"([0-9]{4})(-([0-9]{2})(-([0-9]{2})(T([0-9]{2}):([0-9]{2})(:([0-9]{2})(\.([0-9]+))?)?(Z|(([-+])([0-9]{2}):([0-9]{2})))?)?)?)?"
    DateRegex     = %r'\A\d{4}-\d{2}-\d{2}\z'
    TimeRegex     = %r'\A\d{2}:\d{2}(?:\.\d{1,4})?\z'

    # Checks that object is of given type (and that any custom types
    # comply with interface)
    #
    # @param [Interface] interface API class
    # @param [String] type_string Description of type(s) - comma
    # separated if more than one
    # @param object Value to check check type
    # @return [Boolean] true if ok
		def valid?(interface, type_string, object)
				res = type_string.split(/,/).any? do |type|
          case type
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
          when 'Array'
            object.is_a?(Array)
          when 'Date'
            object.is_a?(String) && DateRegex.match(object) || object.is_a?(Date)
          when 'Time'
            object.is_a?(String) && TimeRegex.match(object) || object.is_a?(Time)
          when 'DateTime'
            object.is_a?(String) && DateTimeRegex.match(object) || object.is_a?(Time)
          when /\AArray\[(.*)\]\z/
            object.is_a?(Array) && object.all? { |value| valid?(interface, $1, value) }
          when 'Value', 'Any', 'void'
            true
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
        end
				#STDERR.puts "#{interface.name}: #{type} - #{object.inspect} - #{res ? "OK" : "FAIL"}"
				res
		end

    # Checks that param hash is valid for API call
    # 
    # @param [Interface] interface API class
    # @param [String] method Method name
    # @param [Hash] data params hash to check
    # @return [Boolean] true if ok
		def valid_params?(interface, method, data)
			about = interface.about[method.to_s]
			return true if about.nil? # No defined params

			params = (about[:params] || [])
			param_names = params.map { |param| param[:name] }

			if params.empty? && data.empty?
				return true
			end

			extra_keys = data.keys - param_names
			unless extra_keys.empty?
				raise "Extra parameters #{extra_keys.inspect} for #{method}."
			end
			
			params.each do |param|
				if data.has_key?(param[:name])
          value = data[param[:name].to_s]
					unless valid?(interface, param[:type], value)
            raise "'#{param[:name]}' should be of type #{param[:type]}, was #{value.class.name}"
          end
				elsif ! param[:required]
					next true
				else
					raise "Missing parameter: '#{param[:name]}' of type #{param[:type]} for #{method}"
				end
			end
		end

    # Checks that result is valid for API call
    # 
    # @param [Interface] interface API class
    # @param [String] method Method name
    # @param [Hash] value Value to check
    # @return [Boolean] true if ok
		def valid_result?(interface, method, value)
			about = interface.about[method.to_s]
			return true if about.nil? # Undefined
			if about[:returns].nil?
				return value.nil?
			end
			valid?(interface, about[:returns][:type], value) or
        raise "Invalid return type: should have been #{about[:returns][:type]}, was #{value.class.name}"
		end
	end

  # Description of JSON object
	class JsonObjectType
		attr_accessor :name, :fields
		def initialize(name, fields)
			@name, @fields = name, fields
			@required = true
		end

    # Check that #object Hash is valid version of this type
		def valid_object?(interface, object, subset = false)
			object.keys.all? { |key| fields.any? { |field| field[:name] == key } } &&
				fields.all? { |field| (object.keys.include?(field[:name]) &&
					Types.valid?(interface, field[:type], object[field[:name]])) || subset || (! field[:required]) }
		end

    # Add field of #name and #type to type description
		def field(name, type, desc, options={})
			@fields << { :name => name, :type => type, :desc => desc, :required => @required }.merge(options)
		end
    # Shortcut to define string field
		def string  name, desc, options={}; field(name, 'String',  desc, options); end
    # Shortcut to define number field
		def number  name, desc, options={}; field(name, 'Number',  desc, options); end
    # Shortcut to define integer field
		def integer name, desc, options={}; field(name, 'Integer', desc, options); end
    # Shortcut to define boolean field
		def boolean name, desc, options={}; field(name, 'Boolean', desc, options); end

    # Make fields defined in block optional by default
		def optional(&block)
			old_required = @required
			begin
				@required = false
				yield(self)
			ensure
				@required = old_required
			end
		end

    # Make fields defined in block required by default
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

end
