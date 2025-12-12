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
  cfg.memory = Sidekiq::Sideline::Memory::RedisHashMemory.new(ttl: 300)
end

class MemoryTask1
  include Sidekiq::Job
  include Sidekiq::Sideline::TypedJob

  sidekiq_options retry: 0

  class Input < Sidekiq::Sideline::Schema
    required :field_name, String
  end

  class Output < Sidekiq::Sideline::Schema
    required :something, String
  end

  def perform(input)
    {"something" => input.field_name}
  end
end

class MemoryTask2
  include Sidekiq::Job
  include Sidekiq::Sideline::TypedJob

  sidekiq_options retry: 0

  class Input < Sidekiq::Sideline::Schema
    required :something, String
  end

  class Output < Sidekiq::Sideline::Schema
    optional :something, String  # you can mutate the input, but only on output
    required :final, String
  end

  def perform(input)
    {
      "something" => input.something.reverse,
      "final" => input.something + "!"
    }
  end
end

workflow = Sidekiq::Sideline::Workflow.new(
  Sidekiq::Sideline::Chain.new(
    Sidekiq::Sideline::Job.new(MemoryTask1, {"field_name" => "hello"}),
    # No args: input is hydrated from workflow memory.
    Sidekiq::Sideline::Job.new(MemoryTask2)
  )
)

run_id = workflow.run

mem = Sidekiq::Sideline.configuration.memory
values = mem.read(run_id, keys: %w[something final], config: Sidekiq.default_configuration)

puts "run_id=#{run_id}"
puts values.inspect
