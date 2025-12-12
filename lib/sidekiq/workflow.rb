# frozen_string_literal: true

require "sidekiq"

require "sidekiq/workflow/version"
require "sidekiq/workflow/constants"

require "sidekiq/workflow/callback_storage"
require "sidekiq/workflow/callback_storage/base"
require "sidekiq/workflow/callback_storage/inline_callback_storage"

require "sidekiq/workflow/memory"
require "sidekiq/workflow/memory/base"
require "sidekiq/workflow/memory/redis_hash_memory"

require "sidekiq/workflow/barrier/at_most_once_barrier"

require "sidekiq/workflow/configuration"
require "sidekiq/workflow/runtime"

require "sidekiq/workflow/schema"
require "sidekiq/workflow/typed_job"

require "sidekiq/workflow/models/chain"
require "sidekiq/workflow/models/group"
require "sidekiq/workflow/models/with_delay"
require "sidekiq/workflow/models/job"

require "sidekiq/workflow/serialize"
require "sidekiq/workflow/completion_callbacks"
require "sidekiq/workflow/noop_worker"
require "sidekiq/workflow/workflow"
require "sidekiq/workflow/middleware"

module Sidekiq
  module Workflow
    class << self
      def configuration
        @configuration ||= Sidekiq::Workflow::Configuration.new
      end

      def configure
        yield(configuration)
      end

      # Refresh the TTL on any barrier keys associated with the currently-running job.
      # This can be useful for long-running jobs in large workflows.
      #
      # No-op unless called from inside a Sidekiq server job execution.
      def extend_ttl!(ttl: nil)
        Sidekiq::Workflow::Runtime.extend_ttl!(ttl: ttl)
      end
    end
  end
end
