# frozen_string_literal: true

ENV["REDIS_URL"] ||= "redis://localhost:6379/15"

require "bundler/setup"
require "logger"
require "redis-client"

require "sidekiq"
require "sidekiq/sideline"

redis_url = ENV.fetch("REDIS_URL")
RedisClient.new(url: redis_url).call("FLUSHDB")

EVENTS_KEY = "sidekiq-sideline:proof:events"

class ProofTask1
  include Sidekiq::Job

  sidekiq_options retry: 0

  def perform(events_key)
    Sidekiq.redis { |c| c.call("RPUSH", events_key, "task1") }
  end
end

class ProofTask2
  include Sidekiq::Job

  sidekiq_options retry: 0

  def perform(events_key)
    sleep 0.2
    Sidekiq.redis { |c| c.call("RPUSH", events_key, "task2") }
  end
end

class ProofTask3
  include Sidekiq::Job

  sidekiq_options retry: 0

  def perform(events_key)
    sleep 0.2
    Sidekiq.redis { |c| c.call("RPUSH", events_key, "task3") }
  end
end

class ProofTask4
  include Sidekiq::Job

  sidekiq_options retry: 0

  def perform(events_key)
    Sidekiq.redis { |c| c.call("RPUSH", events_key, "task4") }
  end
end

instance = Sidekiq.configure_embed do |config|
  config.redis = {url: redis_url}
  config.concurrency = 4
  config.queues = ["default"]

  config.logger = Logger.new($stdout)
  config.logger.level = Logger::WARN

  config.server_middleware do |chain|
    chain.add Sidekiq::Sideline::Middleware
  end
end

instance.run

begin
  workflow = Sidekiq::Sideline::Workflow.new(
    Sidekiq::Sideline::Chain.new(
      Sidekiq::Sideline::Job.new(ProofTask1, EVENTS_KEY),
      Sidekiq::Sideline::Group.new(
        Sidekiq::Sideline::Job.new(ProofTask2, EVENTS_KEY),
        Sidekiq::Sideline::Job.new(ProofTask3, EVENTS_KEY)
      ),
      Sidekiq::Sideline::Job.new(ProofTask4, EVENTS_KEY)
    )
  )

  workflow.run

  deadline = Time.now + 10
  events = []

  loop do
    events = Sidekiq.redis { |c| c.call("LRANGE", EVENTS_KEY, 0, -1) }
    break if events.size >= 4

    raise "Timed out waiting for workflow completion. events=#{events.inspect}" if Time.now > deadline
    sleep 0.05
  end

  ok = events.first == "task1" &&
    events.last == "task4" &&
    events.include?("task2") &&
    events.include?("task3")

  if ok
    puts "PASS: #{events.inspect}"
    exit 0
  else
    warn "FAIL: #{events.inspect}"
    exit 1
  end
ensure
  instance.stop
end
