module JSONRPC2

# @abstract Base authentication class
class Auth
  # Validate an API request
  # 
  # 
  def check(env, rpc)
    true
  end
end

# @abstract Base class for http-based authentication methods, e.g.
# {BasicAuth}
class HttpAuth < Auth
end

# HTTP Basic authentication implementation
class BasicAuth < HttpAuth
  # Create a BasicAuth object
  #
  # @param [Hash<String,String>] users containing containing usernames and passwords
  # @yield [user, pass] Username and password to authenticate
  # @yieldreturn [Boolean] True if credentials are approved
  def initialize(users=nil, &block)
    @users, @lookup = users, block
  end

  # Checks that the client is authorised to access the API
  #
  # @param [Hash,Rack::Request] env Rack environment hash
  # @param [Hash] rpc JSON-RPC2 call content
  # @return [true] Returns true or throws :rack_response, [ 401, ... ]
  def check(env, rpc)
    valid?(env) or
    throw(:rack_response, [401, {
          'Content-Type'     => 'text/html',
          'WWW-Authenticate' => 'Basic realm="API"'
    }, ["<html><head/><body>Authentication Required</body></html>"]])
  end

  def valid?(env)
    auth = env['HTTP_AUTHORIZATION']

    return false unless auth

    m = /Basic\s+([A-Za-z0-9+\/]+=*)/.match(auth)
    user, pass = Base64.decode64(m[1]).split(/:/, 2)
    user_valid?(user, pass)
  end

  # Checks users hash and then the block given to the constructor to
  # verify username / password.
  def user_valid?(user, pass)
    if @users && @users.respond_to?(:[])
      if expected = @users[user]
        return pass == expected
      end
    end
    if @lookup
      return @lookup.call(user, pass)
    end
    false
  end
end
end
