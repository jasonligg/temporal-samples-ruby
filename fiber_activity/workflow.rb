# frozen_string_literal: true

require 'temporalio/workflow'
require_relative 'multiple_fetches_fiber'
require_relative 'multiple_fetches_thread_pool'

module FiberActivity
  class DemoWorkflow < Temporalio::Workflow::Definition
    START_TO_CLOSE_TIMEOUT = 5 * 60 # 5 minutes

    def execute
      # Sequential I/O-blocking work on one worker thread (single-threaded thread-pool executor).
      sequential_multiple_fetches_thread_pool_activity_futures = 5.times.map do
        Temporalio::Workflow::Future.new do
          Temporalio::Workflow.execute_activity(
            FiberActivity::MultipleFetchesThreadPool,
            start_to_close_timeout: START_TO_CLOSE_TIMEOUT
          )
        end
      end

      # Concurrent async I/O work on the fiber executor (single-threaded, many fibers).
      parallel_multiple_fetches_fiber_activity_futures = 5.times.map do
        Temporalio::Workflow::Future.new do
          Temporalio::Workflow.execute_activity(
            FiberActivity::MultipleFetchesFiber,
            start_to_close_timeout: START_TO_CLOSE_TIMEOUT
          )
        end
      end

      Temporalio::Workflow::Future.all_of(
        *sequential_multiple_fetches_thread_pool_activity_futures,
        *parallel_multiple_fetches_fiber_activity_futures
      ).wait

      [
        sequential_multiple_fetches_thread_pool_activity_futures.map(&:result),
        parallel_multiple_fetches_fiber_activity_futures.map(&:result)
      ].flatten
    end
  end
end
