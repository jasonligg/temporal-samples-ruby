# frozen_string_literal: true

require_relative 'workflow'
require_relative 'multiple_fetches_fiber'
require_relative 'multiple_fetches_thread_pool'
require 'async'
require 'logger'
require 'temporalio/client'
require 'temporalio/env_config'
require 'temporalio/worker'

# Load config and apply defaults
args, kwargs = Temporalio::EnvConfig::ClientConfig.load_client_connect_options
args[0] ||= 'localhost:7233' # Default address
args[1] ||= 'default' # Default namespace

# Create a Temporal client
client = Temporalio::Client.connect(*args, **kwargs, logger: Logger.new($stdout, level: Logger::INFO))

# Acitivites that use the fiber executor must be run where the worker is created and run in a fiber context.
Async do
  # Create a single-threaded thread pool executor for the thread pool executor fetch activity.
  # This is only to demonstrate that concurrency is possible through the use of the fiber executor.
  # The default configuration is good enough for most use cases and you usually don't need to customize it.
  single_thread_pool = Temporalio::Worker::ThreadPool.new(max_threads: 1)
  single_thread_executor = Temporalio::Worker::ActivityExecutor::ThreadPool.new(single_thread_pool)

  # Create worker with the activities, workflow, and activity executors
  worker = Temporalio::Worker.new(
    client:,
    task_queue: 'fiber-activity-sample',
    activity_executors: {
      default: single_thread_executor,
      thread_pool: single_thread_executor,
      fiber: Temporalio::Worker::ActivityExecutor::Fiber.default
    },
    workflows: [
      FiberActivity::DemoWorkflow
    ],
    activities: [
      FiberActivity::MultipleFetchesFiber,
      FiberActivity::MultipleFetchesThreadPool
    ]
  )
  # Run the worker until SIGINT
  puts 'Starting worker (ctrl+c to exit)'
  worker.run(shutdown_signals: %w[SIGINT SIGTERM])
end
