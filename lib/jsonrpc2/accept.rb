# Utils for parsing HTTP fields
module JSONRPC2::HTTPUtils
  module_function
  # Converts */* -> /^.*?/.*?$/
  #          text/* -> /^text\/.*?$/
  #          text/html -> /^text\/html$/
  #
  # @param [String] type Media type descriptor
  # @return [Regexp] Regular expression that matches type
  def type_to_regex type
    case type
    when /[*]/
      Regexp.new("^#{type.split(/[*]/).map { |bit| Regexp.quote(bit) }.join('.*?')}$")
    else
      Regexp.new("^#{Regexp.quote(type)}$")
    end
  end

  # Parses the HTTP Accept field and returns a sorted list of prefered
  # types
  #
  # @param field
  def parse_accept field, regex = false
    index = -1
    list = field.split(/,\s*/).map do |media|
     index += 1
     case media
     when /;/
       media, param_str = *media.split(/\s*;\s*(?=q\s*=)/,2)
       params = param_str.to_s.split(/\s*;\s*/).inject({}) { |hash, str|
         k,v = *str.strip.split(/=/).map(&:strip)
         hash.merge(k => v)
       }
       { :q => (params['q'] || 1.0).to_f, :media => media, :index => index }
     else
       { :q => 1.0, :media => media, :index => index }
     end
    end.sort_by { |option| [-1 * option[:q], option[:media].scan(/[*]/).size, option[:index]] }

    final = {}
    list.each do |item|
      q = item[:q]
      final[q] ||= []
      final[q].push(regex ? type_to_regex(item[:media]) : item[:media])
    end

    final.sort_by { |k,v| -1 * k }
  end

  # Selects the clients preferred media/mime type based on Accept header
  #
  # @param [String] http_client_accepts HTTP Accepts header
  # @param [Array<String>] options Media types available
  def which http_client_accepts, options
    return nil unless http_client_accepts

    parse_accept(http_client_accepts, true).each do |preference, types|
      types.each do |type|
        options.each do |option|
          return option if type.match(option)
        end
      end
    end

    nil
  end
end
