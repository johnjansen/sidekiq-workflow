# frozen_string_literal: true

module Sidekiq
  module Workflow
    # TypedJob wraps a job's perform method to validate its input and output.
    #
    # Usage:
    #
    #   class MyTask
    #     include Sidekiq::Job
    #     include Sidekiq::Workflow::TypedJob
    #
    #     class Input < Sidekiq::Workflow::Schema
    #       required :field_name, String
    #     end
    #
    #     class Output < Sidekiq::Workflow::Schema
    #       required :something, String
    #     end
    #
    #     def perform(input)
    #       Output.new("something" => input.field_name)
    #     end
    #   end
    #
    # NOTE: Sidekiq calls `perform(*args)` and does not pass keyword arguments.
    # TypedJob therefore expects a single Hash argument which is converted to `Input`.
    module TypedJob
      def self.included(base)
        base.prepend(self)
      end

      def perform(*args)
        input_schema = resolve_schema(:Input)
        output_schema = resolve_schema(:Output)

        if input_schema
          typed_input = build_typed_input(input_schema, args)
          result = super(typed_input)
        else
          result = super
        end

        return result unless output_schema

        build_typed_output(output_schema, result)
      end

      private

      def resolve_schema(const_name)
        self.class.const_get(const_name)
      rescue NameError
        nil
      end

      def build_typed_input(input_schema, args)
        raise ArgumentError, "TypedJob expects exactly one argument" unless args.size == 1

        raw = args.first
        return raw if raw.is_a?(input_schema)

        raise TypeError, "TypedJob input must be a Hash" unless raw.is_a?(Hash)

        input_schema.new(raw)
      end

      def build_typed_output(output_schema, result)
        return result if result.is_a?(output_schema)

        raise TypeError, "TypedJob output must be a Hash or #{output_schema}" unless result.is_a?(Hash)

        output_schema.new(result)
      end
    end
  end
end
