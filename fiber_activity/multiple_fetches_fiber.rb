# frozen_string_literal: true

require 'json'
require 'temporalio/activity'
require 'async/http/internet/instance'
require_relative 'constants'

# Activity that runs several HTTP requests concurrently on the fiber executor.
#
# In this example, the `async-http` gem is used to kick off HTTP requests but
# control is yielded to the fiber scheduler.
# This is different from the default thread-pool executor, where each request
# blocks and ties up a thread.
#
# The work in an activity must be designed to cooperate with
# the fiber scheduler.
module FiberActivity
  class MultipleFetchesFiber < Temporalio::Activity::Definition
    # Required for fiber-based concurrency; otherwise the worker uses the thread pool.
    activity_executor :fiber

    def execute
      internet = Async::HTTP::Internet.new
      barrier = Async::Barrier.new

      requests = Constants::SIMULATED_LATENCIES_SECONDS.map do |sleep_seconds|
        barrier.async { fetch_one(internet, sleep_seconds) }
      end

      begin
        # Wait for all requests to complete
        barrier.wait
        # The requests are already done, we call wait to get the results
        requests.map(&:wait)
      ensure
        barrier.cancel
        internet.close
      end
    end

    private

    def fetch_one(internet, sleep_seconds)
      logger = Temporalio::Activity::Context.current.logger
      logger.info(
        "thread=#{Thread.current.object_id} fiber=#{Fiber.current.object_id} " \
        "starting fetch (server sleep=#{sleep_seconds}s)"
      )

      url = "#{Constants::BASE_URL}?sleep=#{sleep_seconds}"

      internet.get(url, headers: { 'Accept' => 'application/json' }) do |response|
        logger.info("fetch fiber=#{Fiber.current.object_id} finished (server sleep=#{sleep_seconds}s)")

        {
          activity_executor: 'fiber executor',
          sleep_duration: sleep_seconds,
          thread_object_id: Thread.current.object_id,
          fiber_object_id: Fiber.current.object_id,
          body: JSON.parse(response.read)
        }
      end
    end
  end
end
