# frozen_string_literal: true

module Sidekiq
  module Sideline
    class Chain
      attr_reader :tasks

      def initialize(*tasks)
        @tasks = tasks
      end

      def ==(other)
        other.is_a?(Chain) && tasks == other.tasks
      end

      def to_s
        "Chain(#{tasks})"
      end
    end
  end
end
