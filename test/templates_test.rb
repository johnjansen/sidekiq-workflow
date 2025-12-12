# frozen_string_literal: true

require_relative "helper"

class TemplatesTest < Minitest::Test
  class Task1
    include Sidekiq::Job
    include Sidekiq::Sideline::TypedJob

    sidekiq_options retry: 0

    class Input < Sidekiq::Sideline::Schema
      required :events_key, String
    end

    def perform(input)
      Sidekiq.redis { |c| c.call("RPUSH", input.events_key, "task1") }
    end
  end

  class Task2
    include Sidekiq::Job
    include Sidekiq::Sideline::TypedJob

    sidekiq_options retry: 0

    class Input < Sidekiq::Sideline::Schema
      required :events_key, String
    end

    def perform(input)
      Sidekiq.redis { |c| c.call("RPUSH", input.events_key, "task2") }
    end
  end

  class Task3
    include Sidekiq::Job
    include Sidekiq::Sideline::TypedJob

    sidekiq_options retry: 0

    class Input < Sidekiq::Sideline::Schema
      required :events_key, String
    end

    def perform(input)
      Sidekiq.redis { |c| c.call("RPUSH", input.events_key, "task3") }
    end
  end

  class Task4
    include Sidekiq::Job
    include Sidekiq::Sideline::TypedJob

    sidekiq_options retry: 0

    class Input < Sidekiq::Sideline::Schema
      required :events_key, String
    end

    def perform(input)
      Sidekiq.redis { |c| c.call("RPUSH", input.events_key, "task4") }
    end
  end

  class TemplateInput < Sidekiq::Sideline::Schema
    required :events_key, String
  end

  def setup
    super

    Sidekiq::Sideline::Templates.clear!

    @old_memory = Sidekiq::Sideline.configuration.memory
    Sidekiq::Sideline.configure do |cfg|
      cfg.memory = Sidekiq::Sideline::Memory::RedisHashMemory.new(ttl: 60, key_prefix: "sl:test:mem")
    end
  end

  def teardown
    Sidekiq::Sideline::Templates.clear!

    Sidekiq::Sideline.configure do |cfg|
      cfg.memory = @old_memory
    end

    super
  end

  def read_events(key)
    Sidekiq.redis { |c| c.call("LRANGE", key, 0, -1) }
  end

  def test_run_named_template
    Sidekiq::Sideline::Templates.register("demo", input: TemplateInput) do |_input|
      Sidekiq::Sideline::Chain.new(
        Sidekiq::Sideline::Job.new(Task1),
        Sidekiq::Sideline::Group.new(
          Sidekiq::Sideline::Job.new(Task2),
          Sidekiq::Sideline::Job.new(Task3)
        ),
        Sidekiq::Sideline::Job.new(Task4)
      )
    end

    run_id = Sidekiq::Sideline::Templates.run("demo", {"events_key" => "events"})
    refute_nil run_id

    assert_equal ["demo"], Sidekiq::Sideline::Templates.names

    events = read_events("events")
    assert_equal "task1", events.first
    assert_equal "task4", events.last
    assert_equal %w[task2 task3], events[1, 2].sort
  end
end
