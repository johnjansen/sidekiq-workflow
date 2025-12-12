# frozen_string_literal: true

module Sidekiq
  module Sideline
    # How long barrier keys should live in Redis (in seconds).
    CALLBACK_BARRIER_TTL = 86_400

    # Sidekiq job payload key where completion callbacks are stored.
    OPTION_KEY_CALLBACKS = "sideline_completion_callbacks"

    # Sidekiq job payload key used to identify the sideline run.
    OPTION_KEY_RUN_ID = "sideline_run_id"
  end
end
