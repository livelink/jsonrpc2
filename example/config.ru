$: << File.join(File.dirname(__FILE__),'../lib')
require 'jsonrpc2/interface'

class ::Object::Calculator < JSONRPC2::Interface
  title "JSON-RPC2 Calculator"
  introduction "This interface allows basic maths calculations via JSON-RPC2"
  auth_with JSONRPC2::BasicAuth.new({'user' => 'secretword'})

  section 'Simple Ops' do
      desc 'Multiply two numbers'
      param 'a', 'Number', 'a'
      param 'b', 'Number', 'b'
      result 'Number', 'a * b'
      def mul args
        args['a'] * args['b']
      end

      desc 'Add numbers'
      example "Calculate 1 + 1 = 2", :params => { 'a' => 1, 'b' => 1}, :result => 2

      param 'a', 'Number', 'First number'
      param 'b', 'Number', 'Second number'
      optional 'c', 'Number', 'Third number'
      result 'Number', 'a + b + c'
      def sum args
        val = args['a'] + args['b']
        val += args['c'] if args['c']
        val
      end
  end
end

run Calculator

