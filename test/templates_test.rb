# frozen_string_literal: true

require_relative "helper"

class TemplatesTest < Minitest::Test
  class Task1
    include Sidekiq::Job
    include Sidekiq::Workflow::TypedJob

    sidekiq_options retry: 0

    class Input < Sidekiq::Workflow::Schema
      required :events_key, String
    end

    def perform(input)
      Sidekiq.redis { |c| c.call("RPUSH", input.events_key, "task1") }
    end
  end

  class Task2
    include Sidekiq::Job
    include Sidekiq::Workflow::TypedJob

    sidekiq_options retry: 0

    class Input < Sidekiq::Workflow::Schema
      required :events_key, String
    end

    def perform(input)
      Sidekiq.redis { |c| c.call("RPUSH", input.events_key, "task2") }
    end
  end

  class Task3
    include Sidekiq::Job
    include Sidekiq::Workflow::TypedJob

    sidekiq_options retry: 0

    class Input < Sidekiq::Workflow::Schema
      required :events_key, String
    end

    def perform(input)
      Sidekiq.redis { |c| c.call("RPUSH", input.events_key, "task3") }
    end
  end

  class Task4
    include Sidekiq::Job
    include Sidekiq::Workflow::TypedJob

    sidekiq_options retry: 0

    class Input < Sidekiq::Workflow::Schema
      required :events_key, String
    end

    def perform(input)
      Sidekiq.redis { |c| c.call("RPUSH", input.events_key, "task4") }
    end
  end

  class TemplateInput < Sidekiq::Workflow::Schema
    required :events_key, String
  end

  def setup
    super

    Sidekiq::Workflow::Templates.clear!

    @old_memory = Sidekiq::Workflow.configuration.memory
    Sidekiq::Workflow.configure do |cfg|
      cfg.memory = Sidekiq::Workflow::Memory::RedisHashMemory.new(ttl: 60, key_prefix: "swf:test:mem")
    end
  end

  def teardown
    Sidekiq::Workflow::Templates.clear!

    Sidekiq::Workflow.configure do |cfg|
      cfg.memory = @old_memory
    end

    super
  end

  def read_events(key)
    Sidekiq.redis { |c| c.call("LRANGE", key, 0, -1) }
  end

  def test_run_named_template
    Sidekiq::Workflow::Templates.register("demo", input: TemplateInput) do |_input|
      Sidekiq::Workflow::Chain.new(
        Sidekiq::Workflow::Job.new(Task1),
        Sidekiq::Workflow::Group.new(
          Sidekiq::Workflow::Job.new(Task2),
          Sidekiq::Workflow::Job.new(Task3)
        ),
        Sidekiq::Workflow::Job.new(Task4)
      )
    end

    run_id = Sidekiq::Workflow::Templates.run("demo", {"events_key" => "events"})
    refute_nil run_id

    assert_equal ["demo"], Sidekiq::Workflow::Templates.names

    events = read_events("events")
    assert_equal "task1", events.first
    assert_equal "task4", events.last
    assert_equal %w[task2 task3], events[1, 2].sort
  end
end
