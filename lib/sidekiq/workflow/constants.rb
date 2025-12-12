# frozen_string_literal: true

module Sidekiq
  module Workflow
    # How long barrier keys should live in Redis (in seconds).
    CALLBACK_BARRIER_TTL = 86_400

    # Sidekiq job payload key where completion callbacks are stored.
    OPTION_KEY_CALLBACKS = "workflow_completion_callbacks"
  end
end
