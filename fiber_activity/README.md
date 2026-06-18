# Fiber Activity

This sample intentionally creates a resource-constrained environment — a worker with a **single-threaded** thread pool
— to show how the **fiber executor** unlocks concurrency even when the thread pool is fully occupied with blocking
work.

The workflow (`DemoWorkflow`) launches 5 instances of each activity type and waits for all of them to complete:

* `MultipleFetchesThreadPool` — uses the default thread-pool executor with blocking `Net::HTTP` calls. Because there
  is only one thread, each activity runs its fetches sequentially, and only one activity can execute at a time.
* `MultipleFetchesFiber` — uses the fiber executor with the `async-http` gem. Even though the single thread is tied up
  by the thread-pool activities, the fiber executor runs on its own scheduler and overlaps all I/O concurrently.

Watch the worker logs to see the difference: thread-pool activities complete their fetches in ~15 seconds each (sum of
5+4+3+2+1), while fiber activities complete in ~5 seconds (the longest simulated latency).

To run, first see [README.md](../README.md) for prerequisites. Then install the sample-specific dependencies:

    bundle install --with fiber_activity

Start the test HTTP server (serves on `localhost:7999`):

    bundle exec ruby fiber_activity/server.rb

In another terminal, start the worker:

    bundle exec ruby fiber_activity/worker.rb

In a third terminal, execute the workflow:

    bundle exec ruby fiber_activity/starter.rb

There is also a [test](../test/fiber_activity/demo_workflow_test.rb) that demonstrates mocking both activity types
during the test.
