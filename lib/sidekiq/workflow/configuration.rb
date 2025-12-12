# frozen_string_literal: true

module Sidekiq
  module Workflow
    class Configuration
      attr_accessor :barrier_class
      attr_accessor :barrier_ttl
      attr_accessor :callback_storage

      def initialize
        @barrier_class = Sidekiq::Workflow::Barrier::AtMostOnceBarrier
        @barrier_ttl = Sidekiq::Workflow::CALLBACK_BARRIER_TTL
        @callback_storage = Sidekiq::Workflow::CallbackStorage::InlineCallbackStorage.new
      end
    end
  end
end
