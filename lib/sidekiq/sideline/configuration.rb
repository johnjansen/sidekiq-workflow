# frozen_string_literal: true

module Sidekiq
  module Sideline
    class Configuration
      attr_accessor :barrier_class
      attr_accessor :barrier_ttl
      attr_accessor :callback_storage
      attr_accessor :memory

      def initialize
        @barrier_class = Sidekiq::Sideline::Barrier::AtMostOnceBarrier
        @barrier_ttl = Sidekiq::Sideline::CALLBACK_BARRIER_TTL
        @callback_storage = Sidekiq::Sideline::CallbackStorage::InlineCallbackStorage.new

        # Optional. When configured, TypedJob can hydrate inputs from memory and
        # workflow middleware can persist outputs into memory.
        @memory = nil
      end
    end
  end
end
