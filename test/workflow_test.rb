# frozen_string_literal: true

require_relative "helper"

class WorkflowTest < Minitest::Test
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

  class Task5
    include Sidekiq::Job

    sidekiq_options retry: 0

    def perform(events_key)
      Sidekiq.redis { |c| c.call("RPUSH", events_key, "task5") }
    end
  end

  def read_events(key)
    Sidekiq.redis { |c| c.call("LRANGE", key, 0, -1) }
  end

  def test_chain_then_group_then_chain
    key = "events"

    workflow = Sidekiq::Workflow::Workflow.new(
      Sidekiq::Workflow::Chain.new(
        Sidekiq::Workflow::Job.new(Task1, key),
        Sidekiq::Workflow::Group.new(
          Sidekiq::Workflow::Job.new(Task2, key),
          Sidekiq::Workflow::Job.new(Task3, key)
        ),
        Sidekiq::Workflow::Job.new(Task4, key)
      )
    )

    workflow.run

    events = read_events(key)
    assert_equal "task1", events.first
    assert_equal "task4", events.last
    assert_equal %w[task2 task3], events[1, 2].sort
  end

  def test_nested_chain_inside_group
    key = "events"

    workflow = Sidekiq::Workflow::Workflow.new(
      Sidekiq::Workflow::Chain.new(
        Sidekiq::Workflow::Job.new(Task1, key),
        Sidekiq::Workflow::Group.new(
          Sidekiq::Workflow::Chain.new(
            Sidekiq::Workflow::Job.new(Task2, key),
            Sidekiq::Workflow::Job.new(Task5, key)
          ),
          Sidekiq::Workflow::Job.new(Task3, key)
        ),
        Sidekiq::Workflow::Job.new(Task4, key)
      )
    )

    workflow.run

    events = read_events(key)
    assert_equal "task1", events.first
    assert_equal "task4", events.last

    assert_operator events.index("task2"), :<, events.index("task5")
    assert_operator events.index("task4"), :>, events.index("task5")
    assert_operator events.index("task4"), :>, events.index("task3")
  end
end
