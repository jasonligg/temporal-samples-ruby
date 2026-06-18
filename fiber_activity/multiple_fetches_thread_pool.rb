# frozen_string_literal: true

require 'json'
require 'net/http'
require 'uri'
require 'temporalio/activity'
require_relative 'constants'

# Activity that runs several blocking HTTP requests one after another.
#
# The activity runs on the worker’s default thread-pool executor (no
# `activity_executor :fiber`). Each `Net::HTTP` call blocks until complete, so
# total time is roughly the sum of the server-side sleeps.
#
# Logs include `thread_id` and `fiber_id` so you can see every request runs on the same
# activity thread. Compare with `MultipleFetchesFiber`, which overlaps I/O on one
# thread using multiple fibers.
module FiberActivity
  class MultipleFetchesThreadPool < Temporalio::Activity::Definition
    # No `activity_executor` declaration — uses the worker default (thread pool).
    # The same as setting `activity_executor :default`.

    def execute
      Constants::SIMULATED_LATENCIES_SECONDS.map { |sleep_seconds| fetch_one(sleep_seconds) }
    end

    private

    def fetch_one(sleep_seconds)
      logger = Temporalio::Activity::Context.current.logger
      thread_id = Thread.current.object_id
      logger.info("fetch thread=#{thread_id} starting (server sleep=#{sleep_seconds}s)")

      uri = URI(Constants::BASE_URL)
      uri.query = "sleep=#{sleep_seconds}"
      uri.port = Constants::PORT

      response = Net::HTTP.start(uri.host, uri.port) do |http|
        request = Net::HTTP::Get.new(uri)
        request['Accept'] = 'application/json'
        http.request(request)
      end

      logger.info("fetch thread=#{thread_id} finished (server sleep=#{sleep_seconds}s)")

      {
        activity_executor: 'thread pool executor',
        sleep_duration: sleep_seconds,
        thread_object_id: thread_id,
        fiber_object_id: Fiber.current.object_id,
        body: JSON.parse(response.body)
      }
    end
  end
end
