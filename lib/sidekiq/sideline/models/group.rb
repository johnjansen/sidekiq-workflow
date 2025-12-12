# frozen_string_literal: true

module Sidekiq
  module Sideline
    class Group
      attr_reader :tasks

      def initialize(*tasks)
        @tasks = tasks
      end

      def ==(other)
        other.is_a?(Group) && tasks == other.tasks
      end

      def to_s
        "Group(#{tasks})"
      end
    end
  end
end
