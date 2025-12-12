# frozen_string_literal: true

module Sidekiq
  module Workflow
    class Middleware
      include Sidekiq::ServerMiddleware

      def call(_worker, msg, _queue)
        run_id = msg[Sidekiq::Workflow::OPTION_KEY_RUN_ID]
        callbacks_ref = msg[Sidekiq::Workflow::OPTION_KEY_CALLBACKS]

        result = Sidekiq::Workflow::Runtime.with(run_id: run_id, config: config, callbacks_ref: callbacks_ref) do
          yield
        end

        persist_output(run_id, result)

        return if callbacks_ref.nil?

        completion_callbacks = Sidekiq::Workflow.configuration.callback_storage.retrieve(callbacks_ref)
        Sidekiq::Workflow::CompletionCallbacks.new(config: config).process(completion_callbacks, run_id: run_id)
      end

      private

      def persist_output(run_id, result)
        return if run_id.nil? || run_id.to_s.empty?

        memory = Sidekiq::Workflow.configuration.memory
        return unless memory

        output = if result.is_a?(Sidekiq::Workflow::Schema)
          result.to_h
        elsif result.is_a?(Hash)
          result
        end

        return unless output

        memory.write(run_id, output, config: config)
      end
    end
  end
end
