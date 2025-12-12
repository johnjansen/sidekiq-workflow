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
  cfg.memory = Sidekiq::Workflow::Memory::RedisHashMemory.new(ttl: 300)
end

class MemoryTask1
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

class MemoryTask2
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

workflow = Sidekiq::Workflow::Workflow.new(
  Sidekiq::Workflow::Chain.new(
    Sidekiq::Workflow::Job.new(MemoryTask1, {"field_name" => "hello"}),
    # No args: input is hydrated from workflow memory.
    Sidekiq::Workflow::Job.new(MemoryTask2)
  )
)

run_id = workflow.run

mem = Sidekiq::Workflow.configuration.memory
values = mem.read(run_id, keys: %w[something final], config: Sidekiq.default_configuration)

puts "run_id=#{run_id}"
puts values.inspect
