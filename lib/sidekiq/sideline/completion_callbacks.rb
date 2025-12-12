# frozen_string_literal: true

module Sidekiq
  module Sideline
    class CompletionCallbacks
      def initialize(config: Sidekiq.default_configuration)
        @config = config
      end

      def process(completion_callbacks, run_id: nil)
        while completion_callbacks.any?
          completion_id, remaining_workflow, propagate = completion_callbacks[-1]

          barrier_class = Sidekiq::Sideline.configuration.barrier_class
          barrier_ttl = Sidekiq::Sideline.configuration.barrier_ttl
          barrier = barrier_class.new(completion_id, ttl: barrier_ttl, config: @config)

          break unless barrier.wait(block: false)

          completion_callbacks.pop

          if remaining_workflow
            workflow = Sidekiq::Sideline::Serialize.unserialize_workflow(remaining_workflow)
            Sidekiq::Sideline::Workflow.with_completion_callbacks(
              workflow,
              config: @config,
              completion_callbacks: completion_callbacks,
              run_id: run_id
            ).run
          end

          break unless propagate
        end
      end
    end
  end
end
