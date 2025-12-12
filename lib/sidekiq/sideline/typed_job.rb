# frozen_string_literal: true

module Sidekiq
  module Sideline
    # TypedJob wraps a job's perform method to validate its input and output.
    #
    # Usage:
    #
    #   class MyTask
    #     include Sidekiq::Job
    #     include Sidekiq::Sideline::TypedJob
    #
    #     class Input < Sidekiq::Sideline::Schema
    #       required :field_name, String
    #     end
    #
    #     class Output < Sidekiq::Sideline::Schema
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
        raw = case args.size
        when 0
          {}
        when 1
          args.first
        else
          raise ArgumentError, "TypedJob expects zero or one argument"
        end

        raw = {} if raw.nil?
        return raw if raw.is_a?(input_schema)

        raise TypeError, "TypedJob input must be a Hash" unless raw.is_a?(Hash)

        input_schema.new(hydrate_input_from_memory(input_schema, raw))
      end

      def hydrate_input_from_memory(input_schema, raw)
        memory = Sidekiq::Sideline.configuration.memory
        run_id = Sidekiq::Sideline::Runtime.current_run_id
        config = Sidekiq::Sideline::Runtime.current_config

        return raw unless memory && run_id && config

        keys = input_schema.fields.keys
        from_mem = memory.read(run_id, keys: keys, config: config)
        from_mem.merge(raw)
      end

      def build_typed_output(output_schema, result)
        return result if result.is_a?(output_schema)

        raise TypeError, "TypedJob output must be a Hash or #{output_schema}" unless result.is_a?(Hash)

        output_schema.new(result)
      end
    end
  end
end
