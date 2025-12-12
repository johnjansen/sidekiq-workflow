# frozen_string_literal: true

ENV["REDIS_URL"] ||= "redis://localhost:6379/15"

require "bundler/setup"
require "minitest/autorun"
require "redis-client"

require "sidekiq"
require "sidekiq/testing"
require "sidekiq/sideline"

Sidekiq::Testing.inline!

Sidekiq::Testing.server_middleware do |chain|
  chain.add Sidekiq::Sideline::Middleware
end

def reset_redis!
  RedisClient.new(url: ENV.fetch("REDIS_URL")).call("flushdb")
end

class Minitest::Test
  def setup
    reset_redis!
    Sidekiq::Queues.clear_all if defined?(Sidekiq::Queues)
  end
end
