# frozen_string_literal: true

module Sidekiq
  module Sideline
    class WithDelay
      attr_reader :task
      attr_reader :delay

      # Delay is expressed in milliseconds (to mirror dramatiq-workflow).
      def initialize(task, delay:)
        @task = task
        @delay = delay
      end

      def ==(other)
        other.is_a?(WithDelay) && task == other.task && delay == other.delay
      end

      def to_s
        "WithDelay(#{task}, #{delay})"
      end
    end
  end
end
