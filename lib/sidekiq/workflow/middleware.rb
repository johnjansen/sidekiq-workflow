# frozen_string_literal: true

module Sidekiq
  module Workflow
    class Middleware
      include Sidekiq::ServerMiddleware

      def call(_worker, msg, _queue)
        yield

        callbacks_ref = msg[Sidekiq::Workflow::OPTION_KEY_CALLBACKS]
        return if callbacks_ref.nil?

        completion_callbacks = Sidekiq::Workflow.configuration.callback_storage.retrieve(callbacks_ref)
        Sidekiq::Workflow::CompletionCallbacks.new(config: config).process(completion_callbacks)
      end
    end
  end
end
