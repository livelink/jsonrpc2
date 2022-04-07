## [0.2.0] - 2022-04-07
### Added
- Possibility to define callback for server errors with `JSONRPC2::Interface#on_server_error`

### Fixed
- Fixed regression introduced in 0.1.1 which makes the valid requests crash
- Stopped exposing application internals publicly on errors

## [0.1.1] - 2014-01-04
### Changed
- Improve logging of exceptions / failure

## [0.1.0] - 2014-01-04
### Changed
- Turn on timing & logging of all requests

## [0.0.9] - 2012-09-03
### Changed
- Improve client validation
- Make params optional in request call

## [0.0.8] - 2012-09-03
### Changed
- Add #request to access Rack::Request object
- Make URLs in HTML interface clickable

## [0.0.7] - 2012-08-27
### Changed
- Add bundled Bootstrap assets for HTML test interface

## [0.0.6] - 2012-08-24
### Changed
- Add Date/Time/DateTime as special string types with regex checks for validation

## [0.0.5] - 2012-07-19
### Changed
- Add commandline client jsonrpc2
- Add #auth to access currently authenticated username
