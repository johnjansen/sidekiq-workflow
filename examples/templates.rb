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

Sidekiq::Workflow.configure do |cfg|
  cfg.memory = Sidekiq::Workflow::Memory::RedisHashMemory.new(ttl: 300, key_prefix: "swf:example:mem")
end

class TemplateTask1
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

class TemplateTask2
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

class TemplateTask3
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

class TemplateTask4
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

class DemoInput < Sidekiq::Workflow::Schema
  required :events_key, String
end

Sidekiq::Workflow::Templates.register("demo", input: DemoInput) do |_input|
  Sidekiq::Workflow::Chain.new(
    Sidekiq::Workflow::Job.new(TemplateTask1),
    Sidekiq::Workflow::Group.new(
      Sidekiq::Workflow::Job.new(TemplateTask2),
      Sidekiq::Workflow::Job.new(TemplateTask3)
    ),
    Sidekiq::Workflow::Job.new(TemplateTask4)
  )
end

run_id = Sidekiq::Workflow::Templates.run("demo", {"events_key" => "events"})

events = Sidekiq.redis { |c| c.call("LRANGE", "events", 0, -1) }

puts "template_names=#{Sidekiq::Workflow::Templates.names.inspect}"
puts "run_id=#{run_id}"
puts "events=#{events.inspect}"
