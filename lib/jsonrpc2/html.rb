require 'cgi'
module JSONRPC2
  # HTML output helpers for browseable API interface
  module HTML
  module_function
  # Wrap body in basic bootstrap template using cdn
  def html5(title, body, options={})
    request = options[:request]
    [
    <<-HTML5
<!DOCTYPE html><html>
<head>
<meta http-equiv="content-type" content="text/html; charset=utf-8">
<title>#{title}</title>
#{options[:head]}
<link rel="stylesheet" href="//current.bootstrapcdn.com/bootstrap-v204/css/bootstrap-combined.min.css">
<script src="//current.bootstrapcdn.com/bootstrap-v204/js/bootstrap.min.js"></script>
   <style>
      body {
        padding-top: 60px; /* 60px to make the container go all the way to the bottom of the topbar */
      }
    </style>
</head>
<body>   <div class="navbar navbar-fixed-top">
      <div class="navbar-inner">
        <div class="container">
          <a class="btn btn-navbar" data-toggle="collapse" data-target=".nav-collapse">
            <span class="icon-bar"></span>
            <span class="icon-bar"></span>
            <span class="icon-bar"></span>
          </a>
          <a class="brand" href="#">JSON-RPC Interface</a>
          <div class="nav-collapse">
            <ul class="nav">
              <li class="#{['', '/'].include?(request.path_info) ? 'active' : ''}"><a href="#{request.script_name}/">API Overview</a></li>
            </ul>
          </div><!--/.nav-collapse -->
        </div>
      </div>
    </div>

    <div class="container">#{body}</div>
</body>
</html>
HTML5
  ]
  end

  # Process browser request for #interface
  # @param [JSONRPC2::Interface] interface Interface being accessed
  # @param [Rack::Request] request Request being processed
  # @return [Rack::Response]
  def call(interface, request)
    #require 'pp'; pp interface.about

    if interface.auth_with
      response = catch(:rack_response) do
        interface.auth_with.browser_check(request.env); nil
      end
      return response if response
    end

    case request.path_info
    when /^\/([a-zA-Z_0-9]+)/
      method = $1
      if info = interface.about_method(method)
        if json = request.POST['__json__']
          begin
            data = JSON.parse(json)
            result = interface.new(request.env).dispatch(data)
          rescue => e
            result = e.class.name + ": " + e.message
          end
        end
        [200, {'Content-Type' => 'text/html'}, html5(method,describe(interface, request, info, :result => result), :request => request) ]
      else
        [404, {'Content-Type' => 'text/html'}, html5("Method not found", "<h1>No such method</h1>", :request => request)]
      end
    else
      body = RedCloth.new(interface.to_textile).to_html.gsub(/\<h3\>(.*?)\<\/h3\>/, '<h3><a href="'+request.script_name+'/\1">\1</a></h3>')
      [200, {'Content-Type' => 'text/html'}, 
              html5('Interface: '+interface.name.to_s, body, :request => request)]
    end
  end
  # Returns HTML page describing method
  def describe interface, request, info, options = {}
    params = {}
    if info[:params]
      info[:params].each do |param|
        params[param[:name]] = case param[:type]
        when 'String'
          ""
        when 'Boolean', 'false'
          false
        when 'true'
          true
        when 'null'
          nil
        when 'Number', 'Integer'
          0
        when /^Array/
          []
        else
          {}
        end
      end
    end
    <<-EOS
<h1>Method Info: #{info[:name]}</h1>
#{RedCloth.new(interface.method_to_textile(info)).to_html}

<hr>

<div class="row">
<div class="span6">
<h2>Test method</h2>
</div>
<div class="span6">
<h3>Result</h3>
</div>
</div>
<div class="row">
<div class="span6">
<form method="POST" action="#{request.script_name}/#{info[:name]}">
<textarea name="__json__" cols="60" rows="8" class="span6">
#{CGI.escapeHTML((request.POST['__json__'] || JSON.pretty_unparse({'jsonrpc'=>'2.0', 'method' => info[:name], 'id' => 1, 'params' => params})).strip)}
</textarea>
<div class="form-actions">
<input type="submit" class="btn btn-primary" value="Call Method">
</div>
</form>
</div>
<div class="span6">
<pre style="white-space: prewrap">#{CGI.escapeHTML(JSON.pretty_unparse(JSON.parse(options[:result])))}</pre>
</div>
</div>

EOS
  end
  end
end
