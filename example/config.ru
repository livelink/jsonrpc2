$: << File.join(File.dirname(__FILE__),'../lib')
require 'jsonrpc2/interface'

class Calculator < JSONRPC2::Interface
  section 'Simple Ops' do
      desc 'Multiply two numbers'
      param 'a', 'Number', 'a'
      param 'b', 'Number', 'b'
      result 'Number', 'a * b'
      def mul args
        args['a'] * args['b']
      end

      desc 'Add two numbers'
      param 'a', 'Number', 'a'
      param 'b', 'Number', 'b'
      result 'Number', 'a + b'
      def sum args
        args['a'] + args['b']
      end
  end
end

run Calculator

