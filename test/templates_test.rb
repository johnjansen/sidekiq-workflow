# frozen_string_literal: true

require_relative "helper"

class TemplatesTest < Minitest::Test
  class Task1
    include Sidekiq::Job

    sidekiq_options retry: 0

    def perform(events_key)
      Sidekiq.redis { |c| c.call("RPUSH", events_key, "task1") }
    end
  end

  class Task2
    include Sidekiq::Job

    sidekiq_options retry: 0

    def perform(events_key)
      Sidekiq.redis { |c| c.call("RPUSH", events_key, "task2") }
    end
  end

  class Task3
    include Sidekiq::Job

    sidekiq_options retry: 0

    def perform(events_key)
      Sidekiq.redis { |c| c.call("RPUSH", events_key, "task3") }
    end
  end

  class Task4
    include Sidekiq::Job

    sidekiq_options retry: 0

    def perform(events_key)
      Sidekiq.redis { |c| c.call("RPUSH", events_key, "task4") }
    end
  end

  class Input < Sidekiq::Workflow::Schema
    required :events_key, String
  end

  def setup
    super
    Sidekiq::Workflow::Templates.clear!
  end

  def teardown
    Sidekiq::Workflow::Templates.clear!
    super
  end

  def read_events(key)
    Sidekiq.redis { |c| c.call("LRANGE", key, 0, -1) }
  end

  def test_run_named_template
    Sidekiq::Workflow::Templates.register("demo", input: Input) do |input|
      Sidekiq::Workflow::Chain.new(
        Sidekiq::Workflow::Job.new(Task1, input.events_key),
        Sidekiq::Workflow::Group.new(
          Sidekiq::Workflow::Job.new(Task2, input.events_key),
          Sidekiq::Workflow::Job.new(Task3, input.events_key)
        ),
        Sidekiq::Workflow::Job.new(Task4, input.events_key)
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
