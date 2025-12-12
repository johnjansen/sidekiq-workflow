# frozen_string_literal: true

require "sidekiq"

require "sidekiq/sideline/version"
require "sidekiq/sideline/constants"

require "sidekiq/sideline/callback_storage"
require "sidekiq/sideline/callback_storage/base"
require "sidekiq/sideline/callback_storage/inline_callback_storage"

require "sidekiq/sideline/memory"
require "sidekiq/sideline/memory/base"
require "sidekiq/sideline/memory/redis_hash_memory"

require "sidekiq/sideline/barrier/at_most_once_barrier"

require "sidekiq/sideline/configuration"
require "sidekiq/sideline/runtime"

require "sidekiq/sideline/schema"
require "sidekiq/sideline/typed_job"

require "sidekiq/sideline/models/chain"
require "sidekiq/sideline/models/group"
require "sidekiq/sideline/models/with_delay"
require "sidekiq/sideline/models/job"

require "sidekiq/sideline/templates"

require "sidekiq/sideline/serialize"
require "sidekiq/sideline/completion_callbacks"
require "sidekiq/sideline/noop_worker"
require "sidekiq/sideline/workflow"
require "sidekiq/sideline/middleware"

module Sidekiq
  module Sideline
    class << self
      def configuration
        @configuration ||= Sidekiq::Sideline::Configuration.new
      end

      def configure
        yield(configuration)
      end

      # Refresh the TTL on any barrier keys associated with the currently-running job.
      # This can be useful for long-running jobs in large workflows.
      #
      # No-op unless called from inside a Sidekiq server job execution.
      def extend_ttl!(ttl: nil)
        Sidekiq::Sideline::Runtime.extend_ttl!(ttl: ttl)
      end
    end
  end
end
