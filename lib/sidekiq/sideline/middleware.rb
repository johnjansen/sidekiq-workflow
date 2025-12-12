# frozen_string_literal: true

module Sidekiq
  module Sideline
    class Middleware
      include Sidekiq::ServerMiddleware

      def call(_worker, msg, _queue)
        run_id = msg[Sidekiq::Sideline::OPTION_KEY_RUN_ID]
        callbacks_ref = msg[Sidekiq::Sideline::OPTION_KEY_CALLBACKS]

        result = Sidekiq::Sideline::Runtime.with(run_id: run_id, config: config, callbacks_ref: callbacks_ref) do
          yield
        end

        persist_output(run_id, result)

        return if callbacks_ref.nil?

        completion_callbacks = Sidekiq::Sideline.configuration.callback_storage.retrieve(callbacks_ref)
        Sidekiq::Sideline::CompletionCallbacks.new(config: config).process(completion_callbacks, run_id: run_id)
      end

      private

      def persist_output(run_id, result)
        return if run_id.nil? || run_id.to_s.empty?

        memory = Sidekiq::Sideline.configuration.memory
        return unless memory

        output = if result.is_a?(Sidekiq::Sideline::Schema)
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
