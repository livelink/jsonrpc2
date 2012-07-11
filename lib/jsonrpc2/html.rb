require 'cgi'
module JSONRPC2
  module HTML
  module_function
  def html5(title, body, options={})
    request = options[:request]
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
  end

  def call(interface, request)
    case request.path_info
    when /^\/([a-zA-Z_0-9]+)/
      method = $1
      if json = request.POST['__json__']
        begin
          data = JSON.parse(json)
          result = interface.new(request).dispatch(data)
        rescue => e
          result = e.class.name + ": " + e.message
        end
      end
      [200, {'Content-Type' => 'text/html'}, html5(method,describe(interface, request, method, :result => result), :request => request) ]
    else
      body = RedCloth.new(interface.to_textile).to_html.gsub(/\<h3\>(.*?)\<\/h3\>/, '<h3><a href="'+request.script_name+'/\1">\1</a></h3>')
      [200, {'Content-Type' => 'text/html'}, 
              html5('Interface: '+interface.name.to_s, "<h1>#{interface.name}</h1>" + body, :request => request)]
    end
  end
  def describe interface, request, method, options = {}
    info = interface.about_method(method)
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
<h1>Method Info</h1>
#{RedCloth.new(interface.method_to_textile(info)).to_html}

<hr>
<h2>Test method</h2>
<form method="POST" action="#{request.script_name}/#{method}">
<textarea name="__json__" cols="60" rows="8" class="span8">
#{CGI.escapeHTML((request.POST['__json__'] || JSON.pretty_unparse({'jsonrpc'=>'2.0', 'method' => method, 'id' => 1, 'params' => params})).strip)}
</textarea>
<div class="form-actions">
<input type="submit" class="btn btn-primary" value="Call Method">
</div>
</form>

<h3>Result</h3>
<xmp>
#{options[:result]}
</xmp>

EOS
  end
  end
end
