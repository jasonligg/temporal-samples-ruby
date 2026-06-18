# frozen_string_literal: true

require 'test'
require 'async'
require 'securerandom'
require 'temporalio/testing'
require 'temporalio/worker'
require 'fiber_activity/demo_workflow'

# temporalio-1.3.x: Bridge.fibers_supported uses (major >= 3 && minor >= 3), which
# misclassifies Ruby 4.0.x (minor 0). Restore intent: MRI 3.3+ and Ruby 4+.
module Temporalio
  module Internal
    module Bridge
      def self.fibers_supported
        major, minor = RUBY_VERSION.split('.').take(2).map(&:to_i)
        return false if major.nil? || minor.nil?

        (major > 3) || (major == 3 && minor >= 3)
      end
    end
  end
end

module FiberActivity
  class DemoWorkflowTest < Test
    class MockMultipleFetchesFiber < Temporalio::Activity::Definition
      activity_name :MultipleFetchesFiber
      activity_executor :fiber

      def execute
        [{ activity_executor: 'fiber executor', body: 'mocked fiber fetch' }]
      end
    end

    class MockMultipleFetchesThreadPool < Temporalio::Activity::Definition
      activity_name :MultipleFetchesThreadPool

      def execute
        [{ activity_executor: 'thread pool executor', body: 'mocked thread pool fetch' }]
      end
    end

    def test_demo_workflow
      Temporalio::Testing::WorkflowEnvironment.start_local do |env|
        Async do
          single_thread_pool = Temporalio::Worker::ThreadPool.new(max_threads: 1)
          single_thread_executor = Temporalio::Worker::ActivityExecutor::ThreadPool.new(single_thread_pool)

          worker = Temporalio::Worker.new(
            client: env.client,
            task_queue: "tq-#{SecureRandom.uuid}",
            activity_executors: {
              default: single_thread_executor,
              thread_pool: single_thread_executor,
              fiber: Temporalio::Worker::ActivityExecutor::Fiber.default
            },
            workflows: [DemoWorkflow],
            activities: [MockMultipleFetchesFiber, MockMultipleFetchesThreadPool]
          )

          worker.run do
            result = env.client.execute_workflow(
              DemoWorkflow,
              id: "wf-#{SecureRandom.uuid}",
              task_queue: worker.task_queue
            )

            # 5 thread pool activities + 5 fiber activities, each returning an array of one hash
            assert_equal 10, result.size

            thread_pool_results = result.select { |r| r['activity_executor'] == 'thread pool executor' }
            fiber_results = result.select { |r| r['activity_executor'] == 'fiber executor' }

            assert_equal 5, thread_pool_results.size
            assert_equal 5, fiber_results.size
          end
        end.wait
      end
    end
  end
end
