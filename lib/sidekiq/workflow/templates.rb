# frozen_string_literal: true

module Sidekiq
  module Workflow
    class Template
      attr_reader :name
      attr_reader :input

      def initialize(name, input: nil, &block)
        @name = name.to_s
        raise ArgumentError, "Template name must be non-empty" if @name.empty?
        raise ArgumentError, "Template must be initialized with a block" unless block

        if input && !(input.is_a?(Class) && input < Sidekiq::Workflow::Schema)
          raise ArgumentError, "Template input must be a Sidekiq::Workflow::Schema subclass"
        end

        @input = input
        @builder = block
      end

      def build(params = {})
        input_value = coerce_input(params)
        workflow = @builder.call(input_value)
        validate_workflow!(workflow)
        workflow
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
          Sidekiq::Workflow::Job,
          Sidekiq::Workflow::Chain,
          Sidekiq::Workflow::Group,
          Sidekiq::Workflow::WithDelay
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
          template = Sidekiq::Workflow::Template.new(name, input: input, &block)
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
          workflow = build(name, params)
          Sidekiq::Workflow::Workflow.new(workflow, config: config).run
        end

        def clear!
          @templates.clear
        end

        def names
          @templates.keys.sort
        end
      end
    end
  end
end
