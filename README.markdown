# JSON-RPC2 Ruby Server

A Rack compatible, documenting JSON-RPC 2 server implementation for ruby.

## e.g.

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

## Example

  $ shotgun examples/config.ru

Browse API and test it via a web browser at http://localhost:9393/

