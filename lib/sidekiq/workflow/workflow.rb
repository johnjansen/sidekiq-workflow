# frozen_string_literal: true

require "securerandom"

module Sidekiq
  module Workflow
    class Workflow
      def initialize(workflow, config: Sidekiq.default_configuration)
        @workflow = workflow
        @config = config

        @delay = nil
        @completion_callbacks = nil

        while @workflow.is_a?(Sidekiq::Workflow::WithDelay)
          @delay = (@delay || 0) + @workflow.delay
          @workflow = @workflow.task
        end
      end

      def self.with_completion_callbacks(workflow, config:, completion_callbacks:, delay: nil)
        w = new(workflow, config: config)
        w.instance_variable_set(:@completion_callbacks, completion_callbacks)

        if delay
          existing_delay = w.instance_variable_get(:@delay)
          w.instance_variable_set(:@delay, (existing_delay || 0) + delay)
        end

        w
      end

      def run
        current = @workflow
        completion_callbacks = @completion_callbacks || []

        case current
        when Sidekiq::Workflow::Job
          enqueue_job(current, completion_callbacks)
        when Sidekiq::Workflow::Chain
          tasks = current.tasks.dup
          if tasks.empty?
            schedule_noop(completion_callbacks)
            return
          end

          task = tasks.shift
          if tasks.any?
            completion_id = create_barrier(1)
            completion_callbacks += [[
              completion_id,
              Sidekiq::Workflow::Serialize.serialize_workflow(Sidekiq::Workflow::Chain.new(*tasks)),
              false
            ]]
          end

          Workflow.with_completion_callbacks(task, config: @config, completion_callbacks: completion_callbacks, delay: @delay).run
        when Sidekiq::Workflow::Group
          tasks = current.tasks.dup
          if tasks.empty?
            schedule_noop(completion_callbacks)
            return
          end

          completion_id = create_barrier(tasks.size)
          completion_callbacks += [[completion_id, nil, true]]

          tasks.each do |task|
            Workflow.with_completion_callbacks(task, config: @config, completion_callbacks: completion_callbacks, delay: @delay).run
          end
        else
          raise TypeError, "Unsupported workflow type: #{current.class}"
        end
      end

      private

      def create_barrier(count)
        completion_id = SecureRandom.uuid

        barrier_class = Sidekiq::Workflow.configuration.barrier_class
        barrier_ttl = Sidekiq::Workflow.configuration.barrier_ttl

        barrier = barrier_class.new(completion_id, ttl: barrier_ttl, config: @config)
        barrier.create(count)

        completion_id
      end

      def enqueue_job(job, completion_callbacks)
        item = job.sidekiq_item

        if completion_callbacks.any?
          callbacks_ref = Sidekiq::Workflow.configuration.callback_storage.store(completion_callbacks)
          item[Sidekiq::Workflow::OPTION_KEY_CALLBACKS] = callbacks_ref
        end

        if @delay && @delay.to_f > 0
          # Sidekiq scheduling uses seconds, but WithDelay uses milliseconds.
          item["at"] = Time.now.to_f + (@delay.to_f / 1000.0)
        end

        Sidekiq::Client.new(config: @config).push(item)
      end

      def schedule_noop(completion_callbacks)
        if !@delay || @delay.to_f <= 0
          Sidekiq::Workflow::CompletionCallbacks.new(config: @config).process(completion_callbacks)
          return
        end

        noop = Sidekiq::Workflow::Job.new(Sidekiq::Workflow::NoopWorker)
        Workflow.with_completion_callbacks(noop, config: @config, completion_callbacks: completion_callbacks, delay: @delay).run
      end
    end
  end
end
