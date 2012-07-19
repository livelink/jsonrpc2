module JSONRPC2

# @abstract Base authentication class
class Auth
  # Validate an API request
  # 
  # 
  def client_check(env, rpc)
    true
  end

  # Check authorisation for customers accessing API
  def browser_check(env)
    true
  end

  # Never show internal details of an API object
  def inspect
    "#<#{self.class.name}:#{object_id.to_s(16)}>"
  end
  protected
  # Parse Authorization: header
  #
  # @param [String] auth Header value 
  # @return [Array, false] [username, password] or false
  def parse_basic_auth(auth)
    return false unless auth

    m = /Basic\s+([A-Za-z0-9+\/]+=*)/.match(auth)
    user, pass = Base64.decode64(m[1]).split(/:/, 2)

    [user, pass]
  end

  # Throw a 401 Rack response
  def throw_401
    throw(:rack_response, [401, {
          'Content-Type'     => 'text/html',
          'WWW-Authenticate' => 'Basic realm="API"'
    }, ["<html><head/><body>Authentication Required</body></html>"]])
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
  def client_check(env, rpc)
    browser_check(env)
  end

  # Checks that the browser is authorised to access the API (used by HTML API introspection)
  #
  # @param [Hash,Rack::Request] env Rack environment hash
  # @return [true] Returns true or throws :rack_response, [ 401, ... ]
  def browser_check(env)
    valid?(env) or throw_401
  end

  protected
  # Checks that http auth info is supplied and the username/password combo is valid
  #
  # @param [Hash] env Rack environment
  # @return [Boolean] True if authentication details are ok
  def valid?(env)
    user, pass = parse_basic_auth(env['HTTP_AUTHORIZATION'])

    return false unless user && pass

    user_valid?(user, pass)
  end

  # Checks users hash and then the block given to the constructor to
  # verify username / password.
  # @return [String,false] Username or nothing
  def user_valid?(user, pass)
    if @users && @users.respond_to?(:[])
      if expected = @users[user]
        return user if pass == expected
      end
    end
    if @lookup
      return user if @lookup.call(user, pass)
    end
    false
  end
end
end
