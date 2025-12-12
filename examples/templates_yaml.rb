# frozen_string_literal: true

ENV["REDIS_URL"] ||= "redis://localhost:6379/15"

require "bundler/setup"
require "redis-client"
require "yaml"

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

CONFIG_PATH = File.expand_path("config/enrich_and_index.yml", __dir__)
TEMPLATE_CONFIG = YAML.load_file(CONFIG_PATH).transform_keys(&:to_s)

class FetchDoc
  include Sidekiq::Job
  include Sidekiq::Sideline::TypedJob

  sidekiq_options retry: 0

  class Input < Sidekiq::Sideline::Schema
    required :doc_id, String
  end

  class Output < Sidekiq::Sideline::Schema
    required :doc_text, String
  end

  def perform(input)
    Sidekiq.redis { |c| c.call("RPUSH", "events", "fetch:#{input.doc_id}") }

    {"doc_text" => "doc(#{input.doc_id})"}
  end
end

class EnrichDoc
  include Sidekiq::Job
  include Sidekiq::Sideline::TypedJob

  sidekiq_options retry: 0

  class Input < Sidekiq::Sideline::Schema
    required :doc_text, String
    required :llm_model, String
  end

  class Output < Sidekiq::Sideline::Schema
    required :enriched_text, String
  end

  def perform(input)
    Sidekiq.redis { |c| c.call("RPUSH", "events", "enrich:#{input.llm_model}") }

    {"enriched_text" => "[#{input.llm_model}] #{input.doc_text.upcase}"}
  end
end

class IndexDoc
  include Sidekiq::Job
  include Sidekiq::Sideline::TypedJob

  sidekiq_options retry: 0

  class Input < Sidekiq::Sideline::Schema
    required :doc_id, String
    required :enriched_text, String
    required :index_name, String
  end

  class Output < Sidekiq::Sideline::Schema
    required :indexed, TrueClass
  end

  def perform(input)
    Sidekiq.redis { |c| c.call("RPUSH", "events", "index:#{input.index_name}") }

    # In a real system you would write to the configured index.
    {"indexed" => true}
  end
end

# Bake YAML config into the template by using schema defaults.
EnrichAndIndexInput = Class.new(Sidekiq::Sideline::Schema) do
  required :doc_id, String
  required :llm_model, String, default: TEMPLATE_CONFIG.fetch("llm_model")
  required :index_name, String, default: TEMPLATE_CONFIG.fetch("index_name")
end

Sidekiq::Sideline::Templates.register("enrich_and_index", input: EnrichAndIndexInput) do |_input|
  Sidekiq::Sideline::Chain.new(
    Sidekiq::Sideline::Job.new(FetchDoc),
    Sidekiq::Sideline::Job.new(EnrichDoc),
    Sidekiq::Sideline::Job.new(IndexDoc)
  )
end

# Per-run, only pass the truly run-specific input.
run_id = Sidekiq::Sideline::Templates.run("enrich_and_index", {"doc_id" => "123"})

mem = Sidekiq::Sideline.configuration.memory
values = mem.read(
  run_id,
  keys: %w[doc_id llm_model index_name doc_text enriched_text indexed],
  config: Sidekiq.default_configuration
)

events = Sidekiq.redis { |c| c.call("LRANGE", "events", 0, -1) }

puts "run_id=#{run_id}"
puts "template_config=#{TEMPLATE_CONFIG.inspect}"
puts "memory=#{values.inspect}"
puts "events=#{events.inspect}"
