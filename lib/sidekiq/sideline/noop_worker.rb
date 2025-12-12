# frozen_string_literal: true

module Sidekiq
  module Sideline
    class NoopWorker
      include Sidekiq::Job

      sidekiq_options retry: 0

      def perform(*)
      end
    end
  end
end
