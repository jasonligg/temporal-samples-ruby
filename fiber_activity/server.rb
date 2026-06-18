# frozen_string_literal: true

require 'async/http'
require 'json'
require 'uri'

# Simple HTTP server on http://localhost:7999 for simulating request latency.
#
# Endpoint:
#   GET /*?sleep=<seconds>
#
# Query params:
#   sleep  (Integer, optional) — seconds to sleep before responding; defaults to 0
#
# Response (200, application/json):
#   { "description": "OK", "slept_seconds": <Integer> }

if File.expand_path(__FILE__) == File.expand_path($PROGRAM_NAME)
  endpoint = Async::HTTP::Endpoint.parse('http://localhost:7999')

  Sync do
    server = Async::HTTP::Server.for(endpoint) do |request|
      path = request.path.to_s
      query = path.split('?', 2)[1]
      pair = query && URI.decode_www_form(query).assoc('sleep')
      seconds = pair ? pair[1].to_i : 0

      sleep(seconds)

      Protocol::HTTP::Response[
        200,
        { 'Content-Type' => 'application/json' },
        [{ 'description' => 'OK', 'slept_seconds' => seconds }.to_json]
      ]
    end

    server.run.wait
  end
end
