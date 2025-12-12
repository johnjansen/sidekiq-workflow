# frozen_string_literal: true

module Sidekiq
  module Workflow
    module CallbackStorage
      class InlineCallbackStorage < Base
        def store(callbacks)
          callbacks
        end

        def retrieve(ref)
          ref
        end
      end
    end
  end
end
