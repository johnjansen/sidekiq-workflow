# frozen_string_literal: true

module Sidekiq
  module Workflow
    class CompletionCallbacks
      def initialize(config: Sidekiq.default_configuration)
        @config = config
      end

      def process(completion_callbacks)
        while completion_callbacks.any?
          completion_id, remaining_workflow, propagate = completion_callbacks[-1]

          barrier_class = Sidekiq::Workflow.configuration.barrier_class
          barrier_ttl = Sidekiq::Workflow.configuration.barrier_ttl
          barrier = barrier_class.new(completion_id, ttl: barrier_ttl, config: @config)

          break unless barrier.wait(block: false)

          completion_callbacks.pop

          if remaining_workflow
            workflow = Sidekiq::Workflow::Serialize.unserialize_workflow(remaining_workflow)
            Sidekiq::Workflow::Workflow.with_completion_callbacks(
              workflow,
              config: @config,
              completion_callbacks: completion_callbacks
            ).run
          end

          break unless propagate
        end
      end
    end
  end
end
