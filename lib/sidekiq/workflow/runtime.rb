# frozen_string_literal: true

module Sidekiq
  module Workflow
    module Runtime
      RUN_ID_KEY = :__sidekiq_workflow_run_id
      CONFIG_KEY = :__sidekiq_workflow_config
      CALLBACKS_REF_KEY = :__sidekiq_workflow_callbacks_ref

      def self.current_run_id
        Thread.current[RUN_ID_KEY]
      end

      def self.current_config
        Thread.current[CONFIG_KEY]
      end

      def self.current_callbacks_ref
        Thread.current[CALLBACKS_REF_KEY]
      end

      def self.extend_ttl!(ttl: nil)
        callbacks_ref = current_callbacks_ref
        return false if callbacks_ref.nil?

        config = current_config
        raise "Sidekiq::Workflow runtime is not available (missing Sidekiq config)" if config.nil?

        ttl ||= Sidekiq::Workflow.configuration.barrier_ttl
        raise ArgumentError, "ttl must be a positive Integer" unless ttl.is_a?(Integer) && ttl.positive?

        completion_callbacks = Sidekiq::Workflow.configuration.callback_storage.retrieve(callbacks_ref)
        barrier_ids = completion_callbacks.map { |completion_id, _remaining_workflow, _propagate| completion_id }.uniq
        return false if barrier_ids.empty?

        config.redis do |conn|
          conn.pipelined do |pipe|
            barrier_ids.each do |barrier_id|
              pipe.call("EXPIRE", barrier_id, ttl)
              pipe.call("EXPIRE", "#{barrier_id}_ran", ttl)
            end
          end
        end

        true
      end

      def self.with(run_id:, config:, callbacks_ref: nil)
        old_run_id = Thread.current[RUN_ID_KEY]
        old_config = Thread.current[CONFIG_KEY]
        old_callbacks_ref = Thread.current[CALLBACKS_REF_KEY]

        Thread.current[RUN_ID_KEY] = run_id
        Thread.current[CONFIG_KEY] = config
        Thread.current[CALLBACKS_REF_KEY] = callbacks_ref

        yield
      ensure
        Thread.current[RUN_ID_KEY] = old_run_id
        Thread.current[CONFIG_KEY] = old_config
        Thread.current[CALLBACKS_REF_KEY] = old_callbacks_ref
      end
    end
  end
end
