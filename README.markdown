# JSON-RPC2 Ruby Server

A Rack compatible, documenting JSON-RPC 2 DSL/server implementation for ruby.

## Changes

* 0.1.1 - 4-Jan-2013
  Improve logging of exceptions / failure

* 0.1.0 - 4-Jan-2013
  Turn on timing & logging of all requests

* 0.0.9 - 3-Sep-2012
  Improve client validation
  Make params optional in request call

* 0.0.8 - 3-Sep-2012
  Add #request to access Rack::Request object
  Make URLs in HTML interface clickable

* 0.0.7 - 27-Aug-2012
  Add bundled Bootstrap assets for HTML test interface

* 0.0.6 - 24-Aug-2012
  Add Date/Time/DateTime as special string types with regex checks for validation

* 0.0.5 - 19-Jul-2012
  Add commandline client jsonrpc2
  Add #auth to access currently authenticated username

## Features

* Inline documentation
* Type checking for parameters and return values
* Authentication support - including HTTP Basic Authentication
* Rack mountable
* Interactive browser based API testing

## Example

```ruby
class Calculator < JSONRPC2::Interface
  title "JSON-RPC2 Calculator"
  introduction "This interface allows basic maths calculations via JSON-RPC2"
  auth_with JSONRPC2::BasicAuth.new({'apiuser' => 'secretword'})

  section 'Simple Ops' do
      desc 'Multiply two numbers'
      param 'a', 'Number', 'First number'
      param 'b', 'Number', 'Second number'
      result 'Number', 'a * b'
      def mul args
        args['a'] * args['b']
      end

      desc 'Add numbers'
      param 'a', 'Number', 'First number'
      param 'b', 'Number', 'Second number'
      optional 'c', 'Number', 'Third number'
      example 'Calculate 1 + 1', :params => { 'a' => 1, 'b' => 1}, :result => 2
      result 'Number', 'a + b + c'
      def sum args
        val = args['a'] + args['b']
        val += args['c'] if args['c']
        val
      end
  end
end
```

To run example:
```bash
$ gem install shotgun # unless it's already installed
$ shotgun example/config.ru
```

Browse API and test it via a web browser at http://localhost:9393/

## Inline documentation

Use built in helper methods to declare complex types and function
parameters before defining method calls.

### Custom type definitions

e.g.

    type "Address" do |t|
      t.string "street", "Street name"
      t.string "city", "City"
      ...
    end

    type "Person" do |t|
      t.string "name", "Person's name"
      t.number "age", "Person's age"
      t.boolean "is_member", "Is person a member of our club?"
      t.optional do
        t.field "address", "Address", "Address of person"
      end
    end

#### type "Name", &block

> Declare a JSON object type with named keys and value types

#### field "Name", "Type", "Description"
#### string "Name", "Description"
#### number "Name", "Description"
#### integer "Name", "Description"
#### boolean "Name", "Description"

> Describes the members of a JSON object - fields can be of any known type (see {JSONRPC2::Types} for details).

#### optional &block
#### required &block

> Use blocks to specify whether an object field is required or optional

---

### Method annotations

e.g.

         desc 'Add numbers'
         param 'a', 'Number', 'First number'
         param 'b', 'Number', 'Second number'
         optional 'c', 'Number', 'Third number'
         example 'Calculate 1 + 1', :params => { 'a' => 1, 'b' => 1}, :result => 2
         result 'Number', 'a + b + c'
         def sum args
           val = args['a'] + args['b']
           val += args['c'] if args['c']
           val
         end

#### desc "Description of method"

> Short description of what the method does

#### param "Name", "Type", "Description"

or

#### optional "Name", "Type", "Description"

> Description of a named parameter for the method, including type and purpose (see {JSONRPC2::Types} for type details)

#### result "Type", "Description"

> Type and description of return value for method (see {JSONRPC2::Types} for type details)

#### example "Description", "Detail"

> Describe example usage

#### example "Description", { :params => { ... }, :result => value }

> Describe example usage and valid result (NB: values specified for both params and result are checked against the method type descriptions and generating docs will throw an error if the values are invalid).

#### example "Description", { :params => { ... }, :error => value }

> Describe example usage and sample error (NB: values specified for params are checked against the method type descriptions and generating docs throws an error if the values are invalid).

#### nodoc

> Don't include next method in documentation

---

### Interface annotations

e.g.

    title "Calculator interface"
    introduction "Very simple calculator interface"

    section "Entry points" do
      ...
    end

#### title "Title"

> Set title for interface

#### introduction "Introduction/description of interface"

> Add a basic introduction for the API

#### section "Name", &block

> Group methods into logical sections for documentation purposes

### Authentication

#### auth_with Authenticator

e.g.
    auth_with JSONRPC2::BasicAuth.new({'apiuser' => 'secretword'})

> Specify authentication method that should be used to verify the access credentials before printing.  See {JSONRPC2::BasicAuth} for examples/info.
