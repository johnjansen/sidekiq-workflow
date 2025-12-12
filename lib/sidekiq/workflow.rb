# frozen_string_literal: true

require "sidekiq"

require "sidekiq/workflow/version"
require "sidekiq/workflow/constants"

require "sidekiq/workflow/callback_storage"
require "sidekiq/workflow/callback_storage/base"
require "sidekiq/workflow/callback_storage/inline_callback_storage"

require "sidekiq/workflow/barrier/at_most_once_barrier"

require "sidekiq/workflow/configuration"

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
    end
  end
end
