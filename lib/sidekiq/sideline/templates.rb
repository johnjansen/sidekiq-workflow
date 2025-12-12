# frozen_string_literal: true

module Sidekiq
  module Sideline
    class Template
      attr_reader :name
      attr_reader :input

      def initialize(name, input: nil, &block)
        @name = name.to_s
        raise ArgumentError, "Template name must be non-empty" if @name.empty?
        raise ArgumentError, "Template must be initialized with a block" unless block

        if input && !(input.is_a?(Class) && input < Sidekiq::Sideline::Schema)
          raise ArgumentError, "Template input must be a Sidekiq::Sideline::Schema subclass"
        end

        @input = input
        @builder = block
      end

      def build(params = {})
        workflow, _input_value = build_with_input(params)
        workflow
      end

      def build_with_input(params = {})
        input_value = coerce_input(params)
        workflow = @builder.call(input_value)
        validate_workflow!(workflow)
        [workflow, input_value]
      end

      def input_hash(params = {})
        input_value = coerce_input(params)

        return input_value.to_h if input_value.is_a?(Sidekiq::Sideline::Schema)

        raise TypeError, "Template input must be a Hash" unless input_value.is_a?(Hash)
        input_value
      end

      private

      def coerce_input(params)
        return params if input.nil? && params.is_a?(Hash)
        raise ArgumentError, "Template params must be a Hash" if input.nil?

        return params if params.is_a?(input)
        raise TypeError, "Template input must be a Hash or #{input}" unless params.is_a?(Hash)

        input.new(params)
      end

      def validate_workflow!(workflow)
        allowed = [
          Sidekiq::Sideline::Job,
          Sidekiq::Sideline::Chain,
          Sidekiq::Sideline::Group,
          Sidekiq::Sideline::WithDelay
        ]

        return if allowed.any? { |klass| workflow.is_a?(klass) }

        raise TypeError,
          "Template must return a workflow node (Job/Chain/Group/WithDelay), got #{workflow.class}"
      end
    end

    module Templates
      @templates = {}

      class << self
        def register(name, input: nil, &block)
          template = Sidekiq::Sideline::Template.new(name, input: input, &block)
          key = template.name

          raise ArgumentError, "Template already registered: #{key}" if @templates.key?(key)

          @templates[key] = template
        end

        def fetch(name)
          @templates.fetch(name.to_s)
        end

        def build(name, params = {})
          fetch(name).build(params)
        end

        def run(name, params = {}, config: Sidekiq.default_configuration)
          template = fetch(name)
          workflow, input_value = template.build_with_input(params)

          wf = Sidekiq::Sideline::Workflow.new(workflow, config: config)
          seed_memory(wf.run_id, input_value, config: config)

          wf.run
        end

        def clear!
          @templates.clear
        end

        def names
          @templates.keys.sort
        end

        private

        def seed_memory(run_id, input_value, config:)
          memory = Sidekiq::Sideline.configuration.memory
          return false unless memory

          hash = if input_value.is_a?(Sidekiq::Sideline::Schema)
            input_value.to_h
          else
            input_value
          end

          return false unless hash.is_a?(Hash)

          memory.write(run_id, hash, config: config)
          true
        end
      end
    end
  end
end
