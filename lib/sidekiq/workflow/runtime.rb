# frozen_string_literal: true

module Sidekiq
  module Workflow
    module Runtime
      RUN_ID_KEY = :__sidekiq_workflow_run_id
      CONFIG_KEY = :__sidekiq_workflow_config

      def self.current_run_id
        Thread.current[RUN_ID_KEY]
      end

      def self.current_config
        Thread.current[CONFIG_KEY]
      end

      def self.with(run_id:, config:)
        old_run_id = Thread.current[RUN_ID_KEY]
        old_config = Thread.current[CONFIG_KEY]

        Thread.current[RUN_ID_KEY] = run_id
        Thread.current[CONFIG_KEY] = config

        yield
      ensure
        Thread.current[RUN_ID_KEY] = old_run_id
        Thread.current[CONFIG_KEY] = old_config
      end
    end
  end
end
