# frozen_string_literal: true

module Sidekiq
  module Workflow
    module Serialize
      def self.serialize_workflow(workflow)
        return nil if workflow.nil?

        case workflow
        when Sidekiq::Workflow::Job
          workflow.to_h.merge("__type__" => "job")
        when Sidekiq::Workflow::Chain
          {
            "__type__" => "chain",
            "children" => workflow.tasks.map { |task| serialize_workflow(task) }
          }
        when Sidekiq::Workflow::Group
          {
            "__type__" => "group",
            "children" => workflow.tasks.map { |task| serialize_workflow(task) }
          }
        when Sidekiq::Workflow::WithDelay
          {
            "__type__" => "with_delay",
            "delay" => workflow.delay,
            "task" => serialize_workflow(workflow.task)
          }
        else
          raise TypeError, "Unsupported workflow type: #{workflow.class}"
        end
      end

      def self.unserialize_workflow(workflow)
        result = unserialize_workflow_or_nil(workflow)
        raise ArgumentError, "Cannot unserialize a workflow that resolves to nil" if result.nil?
        result
      end

      def self.unserialize_workflow_or_nil(workflow)
        return nil if workflow.nil?
        raise TypeError, "Unsupported data type: #{workflow.class}" unless workflow.is_a?(Hash)

        case workflow.fetch("__type__")
        when "job"
          Sidekiq::Workflow::Job.from_h(workflow)
        when "chain"
          children = workflow.fetch("children")
          Sidekiq::Workflow::Chain.new(*children.map { |child| unserialize_workflow(child) })
        when "group"
          children = workflow.fetch("children")
          Sidekiq::Workflow::Group.new(*children.map { |child| unserialize_workflow(child) })
        when "with_delay"
          Sidekiq::Workflow::WithDelay.new(
            unserialize_workflow(workflow.fetch("task")),
            delay: workflow.fetch("delay")
          )
        else
          raise TypeError, "Unsupported workflow type: #{workflow["__type__"]}"
        end
      end
    end
  end
end
