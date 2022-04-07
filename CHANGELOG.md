* UNRELEASED
  Fix the regression introduced in 0.1.1 which makes the valid requests crash
  Stop exposing application internals publicly on errors
  Make it possible to define callback for server errors with `JSONRPC2::Interface#on_server_error`

* 0.1.1 - 4-Jan-2014
  Improve logging of exceptions / failure

* 0.1.0 - 4-Jan-2014
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
