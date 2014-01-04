$: << File.join(File.dirname(__FILE__),'../lib')
require 'jsonrpc2/interface'
require 'rack/logger'

class ::Object::Calculator < JSONRPC2::Interface
  title "JSON-RPC2 Calculator"
  introduction "This interface allows basic maths calculations via JSON-RPC2"
  auth_with JSONRPC2::BasicAuth.new({'user' => 'secretword', 'admin' => 'password'})

  section 'Simple Ops' do
      desc 'Multiply two numbers'
      param 'a', 'Number', 'a'
      param 'b', 'Number', 'b'
      result 'Number', 'a * b'
      def mul
        raise JSONRPC2::KnownError, [123, "Don't like negative numbers", params] if params['a'] < 0 or params['b'] < 0
        params['a'] * params['b']
      end

      desc 'Add numbers'
      example "Calculate 1 + 1 = 2", :params => { 'a' => 1, 'b' => 1}, :result => 2

      param 'a', 'Number', 'First number'
      param 'b', 'Number', 'Second number'
      optional 'c', 'Number', 'Third number'
      result 'Number', 'a + b + c'
      def sum
        val = params['a'] + params['b']
        val += params['c'] if params['c']

        return 42 if auth == 'admin'

        val
      end
  end
end

use Rack::Logger
run Calculator

