# frozen_string_literal: true

module FiberActivity
  module Constants
    PORT = 7999
    BASE_URL = "http://localhost:#{PORT}".freeze

    # Server-side sleep (seconds) per request. We set different values so completions are staggered.
    # The activity takes as long as the longest request.
    SIMULATED_LATENCIES_SECONDS = [5, 4, 3, 2, 1].freeze
  end
end
