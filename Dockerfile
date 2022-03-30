FROM ruby:3

RUN mkdir /srv/www
WORKDIR /srv/www
COPY jsonrpc2.gemspec .
COPY Gemfile .
COPY lib/jsonrpc2/version.rb lib/jsonrpc2/
RUN bundle install
