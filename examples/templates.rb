# frozen_string_literal: true

ENV["REDIS_URL"] ||= "redis://localhost:6379/15"

require "bundler/setup"
require "redis-client"

require "sidekiq"
require "sidekiq/testing"
require "sidekiq/workflow"

Sidekiq::Testing.inline!

Sidekiq::Testing.server_middleware do |chain|
  chain.add Sidekiq::Workflow::Middleware
end

RedisClient.new(url: ENV.fetch("REDIS_URL")).call("FLUSHDB")

class TemplateTask1
  include Sidekiq::Job

  sidekiq_options retry: 0

  def perform(events_key)
    Sidekiq.redis { |c| c.call("RPUSH", events_key, "task1") }
  end
end

class TemplateTask2
  include Sidekiq::Job

  sidekiq_options retry: 0

  def perform(events_key)
    Sidekiq.redis { |c| c.call("RPUSH", events_key, "task2") }
  end
end

class TemplateTask3
  include Sidekiq::Job

  sidekiq_options retry: 0

  def perform(events_key)
    Sidekiq.redis { |c| c.call("RPUSH", events_key, "task3") }
  end
end

class TemplateTask4
  include Sidekiq::Job

  sidekiq_options retry: 0

  def perform(events_key)
    Sidekiq.redis { |c| c.call("RPUSH", events_key, "task4") }
  end
end

class DemoInput < Sidekiq::Workflow::Schema
  required :events_key, String
end

Sidekiq::Workflow::Templates.register("demo", input: DemoInput) do |input|
  Sidekiq::Workflow::Chain.new(
    Sidekiq::Workflow::Job.new(TemplateTask1, input.events_key),
    Sidekiq::Workflow::Group.new(
      Sidekiq::Workflow::Job.new(TemplateTask2, input.events_key),
      Sidekiq::Workflow::Job.new(TemplateTask3, input.events_key)
    ),
    Sidekiq::Workflow::Job.new(TemplateTask4, input.events_key)
  )
end

run_id = Sidekiq::Workflow::Templates.run("demo", {"events_key" => "events"})

events = Sidekiq.redis { |c| c.call("LRANGE", "events", 0, -1) }

puts "template_names=#{Sidekiq::Workflow::Templates.names.inspect}"
puts "run_id=#{run_id}"
puts "events=#{events.inspect}"
