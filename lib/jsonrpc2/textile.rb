require 'redcloth'

module JSONRPC2
  # Textile documentation output functions
  module TextileEmitter
    # Returns interface description in textile
		def to_textile
			return nil if @about.nil? or @about.empty?
			str = ""

      if @title
				str << "h1. #{@title}\n"
      else
        str << "h1. #{name}\n"
      end

			if @introduction
				str << "\nh2. Introduction\n\n#{@introduction}\n"
			end

      # Output type descriptions
      #
			unless @types.nil? or @types.empty?
				str << "\n\nh2. Types\n"
				@types.sort_by { |k,v| k }.each do |k,type|
					str << "\n\nh5. #{k} type\n"

					str << "\n|_. Field |_. Type |_. Required? |_. Description |"
					type.fields.each do |field|
						str << "\n| @#{field[:name]}@ | @#{field[:type]}@ | #{field[:required] ? 'Yes' : 'No'} | #{field[:desc]} |"
					end
					str << "\n"
				end
			end


      # Output method definitions
      #
			(@sections||[]).each do |section|
				str << "\n\nh2. #{section[:name]}\n"
				if section[:summary]
					str << "\n#{section[:summary]}\n"
				end

				str += to_textile_group(section).to_s
			end

			miscfn = to_textile_group({:name => nil})
			if miscfn
				str << "\n\nh2. Misc functions\n" if @sections && ! @sections.empty?
				str << miscfn
			end

			str
		end
    # Returns method description in textile
    def method_to_textile(info)
      str = ''
      str << "\n\nh3. #{info[:name]}\n"
      str << "\n#{info[:desc]}\n" if info[:desc]
      str << "\n\nh5. Params\n"
      if info[:params].nil?
        str << "\n* _None_\n"
      elsif info[:params].is_a?(Array)
        str << "\n|_. Name |_. Type |_. Required |_. Description |\n"
        info[:params].each do |param|
          str << "| @#{param[:name]}@ | @#{param[:type]}@ | #{param[:required] ? 'Yes' : 'No'} | #{param[:desc]} |\n"
        end
      end

      if res = info[:returns]
        str << "\n\nh5. Result\n"
        str << "\n* @#{res[:type]}@"
        str << " - #{res[:desc]}" if res[:desc]
        str << "\n"
      else
        str << "\n\nh5. Result\n"
        str << "\n* @null@"
      end

      if examples = info[:examples]
        str << "\n\nh5. Sample usage\n"

        nice_json = lambda do |data|
          JSON.pretty_unparse(data).gsub(/\n\n+/,"\n").gsub(/[{]\s+[}]/m, '{ }').gsub(/\[\s+\]/m, '[ ]')
        end
        examples.each do |ex|
          str << "\n#{ex[:desc]}\n"
          code = ex[:code]
          if code.is_a?(String)
            str << "\nbc. #{ex[:code]}\n"
          elsif code.is_a?(Hash) && code.has_key?(:params) && (code.has_key?(:result) || code.has_key?(:error))

            str << "\nbc. "
            if code[:result] # ie. we expect success
              unless JSONRPC2::Types.valid_params?(self, info[:name], code[:params])
                raise "Invalid example params for #{info[:name]} / #{ex[:desc]}"
              end
            end
            input = { 'jsonrpc' => 2.0, 'method' => info[:name], 'params' => code[:params], 'id' => 0 }
            str << "--> #{nice_json.call(input)}\n"

            if code[:error]
              error = { 'jsonrpc' => 2.0, 'error' => code[:error], 'id' => 0 }
              str << "<-- #{nice_json.call(error)}\n"
            elsif code[:result]
              unless JSONRPC2::Types.valid_result?(self, info[:name], code[:result])
                raise "Invalid result example for #{info[:name]} / #{ex[:desc]}"
              end

              result = { 'jsonrpc' => 2.0, 'result' => code[:result], 'id' => 0 }
              str << "<-- #{nice_json.call(result)}\n"
            end
          end
        end
      end

      str
    end
    # Gets method docs for method #name
    def about_method(name)
      @about[name.to_s]
    end
    # Returns documentation #section contents in textile
		def to_textile_group(section)
			list = @about.values.select { |info| info[:section] == section[:name] }

			return nil if list.empty?

			str = ''

			list.sort_by { |info| info[:index] }.each do |info|
        str << method_to_textile(info)
			end

			str
		end

  end
end
