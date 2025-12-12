# frozen_string_literal: true

require_relative "helper"

class RuntimeTest < Minitest::Test
  class Task1
    include Sidekiq::Job

    sidekiq_options retry: 0

    class << self
      attr_accessor :barrier_id
    end

    def perform
      callbacks_ref = Sidekiq::Sideline::Runtime.current_callbacks_ref
      self.class.barrier_id = callbacks_ref[-1][0]

      Sidekiq::Sideline.extend_ttl!(ttl: 60)
    end
  end

  class Task2
    include Sidekiq::Job

    sidekiq_options retry: 0

    def perform
      # noop
    end
  end

  def setup
    super

    @old_barrier_ttl = Sidekiq::Sideline.configuration.barrier_ttl
    Sidekiq::Sideline.configure do |cfg|
      cfg.barrier_ttl = 2
    end
  end

  def teardown
    Sidekiq::Sideline.configure do |cfg|
      cfg.barrier_ttl = @old_barrier_ttl
    end

    super
  end

  def test_extend_ttl_refreshes_barrier_keys
    workflow = Sidekiq::Sideline::Workflow.new(
      Sidekiq::Sideline::Chain.new(
        Sidekiq::Sideline::Job.new(Task1),
        Sidekiq::Sideline::Job.new(Task2)
      )
    )

    workflow.run

    barrier_id = Task1.barrier_id
    refute_nil barrier_id

    redis = RedisClient.new(url: ENV.fetch("REDIS_URL"))

    ttl = redis.call("TTL", barrier_id).to_i
    ttl_ran = redis.call("TTL", "#{barrier_id}_ran").to_i

    assert_operator ttl, :>=, 50
    assert_operator ttl_ran, :>=, 50
  end
end
