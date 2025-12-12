# frozen_string_literal: true

ENV["REDIS_URL"] ||= "redis://localhost:6379/15"

require "bundler/setup"
require "redis-client"

require "sidekiq"
require "sidekiq/testing"
require "sidekiq/sideline"

Sidekiq::Testing.inline!

Sidekiq::Testing.server_middleware do |chain|
  chain.add Sidekiq::Sideline::Middleware
end

RedisClient.new(url: ENV.fetch("REDIS_URL")).call("FLUSHDB")

Sidekiq::Sideline.configure do |cfg|
  cfg.memory = Sidekiq::Sideline::Memory::RedisHashMemory.new(ttl: 300, key_prefix: "sl:example:mem")
end

class TemplateTask1
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

class TemplateTask2
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

class TemplateTask3
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

class TemplateTask4
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

class DemoInput < Sidekiq::Sideline::Schema
  required :events_key, String
end

Sidekiq::Sideline::Templates.register("demo", input: DemoInput) do |_input|
  Sidekiq::Sideline::Chain.new(
    Sidekiq::Sideline::Job.new(TemplateTask1),
    Sidekiq::Sideline::Group.new(
      Sidekiq::Sideline::Job.new(TemplateTask2),
      Sidekiq::Sideline::Job.new(TemplateTask3)
    ),
    Sidekiq::Sideline::Job.new(TemplateTask4)
  )
end

run_id = Sidekiq::Sideline::Templates.run("demo", {"events_key" => "events"})

events = Sidekiq.redis { |c| c.call("LRANGE", "events", 0, -1) }

puts "template_names=#{Sidekiq::Sideline::Templates.names.inspect}"
puts "run_id=#{run_id}"
puts "events=#{events.inspect}"
