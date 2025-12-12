# frozen_string_literal: true

require_relative "helper"

class MemoryTest < Minitest::Test
  class Task1
    include Sidekiq::Job
    include Sidekiq::Workflow::TypedJob

    sidekiq_options retry: 0

    class Input < Sidekiq::Workflow::Schema
      required :field_name, String
    end

    class Output < Sidekiq::Workflow::Schema
      required :something, String
    end

    def perform(input)
      {"something" => input.field_name}
    end
  end

  class Task2
    include Sidekiq::Job
    include Sidekiq::Workflow::TypedJob

    sidekiq_options retry: 0

    class Input < Sidekiq::Workflow::Schema
      required :something, String
    end

    class Output < Sidekiq::Workflow::Schema
      required :final, String
    end

    def perform(input)
      {"final" => "#{input.something}!"}
    end
  end

  def setup
    super

    @old_memory = Sidekiq::Workflow.configuration.memory
    Sidekiq::Workflow.configure do |cfg|
      cfg.memory = Sidekiq::Workflow::Memory::RedisHashMemory.new(ttl: 60, key_prefix: "swf:test:mem")
    end
  end

  def teardown
    Sidekiq::Workflow.configure do |cfg|
      cfg.memory = @old_memory
    end

    super
  end

  def test_memory_persists_output_and_hydrates_next_task_input
    workflow = Sidekiq::Workflow::Workflow.new(
      Sidekiq::Workflow::Chain.new(
        Sidekiq::Workflow::Job.new(Task1, {"field_name" => "hello"}),
        Sidekiq::Workflow::Job.new(Task2)
      )
    )

    run_id = workflow.run

    mem = Sidekiq::Workflow.configuration.memory
    data = mem.read(run_id, keys: %w[something final], config: Sidekiq.default_configuration)

    assert_equal "hello", data["something"]
    assert_equal "hello!", data["final"]
  end
end
