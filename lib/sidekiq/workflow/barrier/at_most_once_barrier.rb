# frozen_string_literal: true

module Sidekiq
  module Workflow
    module Barrier
      class AtMostOnceBarrier
        attr_accessor :config

        def initialize(key, ttl: Sidekiq::Workflow::CALLBACK_BARRIER_TTL, config: Sidekiq.default_configuration)
          @key = key
          @ttl = ttl
          @ran_key = "#{key}_ran"
          @config = config
        end

        def create(parties)
          config.redis do |conn|
            conn.call("SETEX", @key, @ttl, parties)
            conn.call("SETEX", @ran_key, @ttl, -1)
          end
        end

        def wait(block: false)
          raise ArgumentError, "Blocking is not supported by AtMostOnceBarrier" if block

          config.redis do |conn|
            remaining = conn.call("DECR", @key)
            return false if remaining.to_i > 0

            # First completion to observe the barrier reaching (or passing) 0 is allowed
            # to release it. Subsequent completions must not re-release.
            ran = conn.call("INCRBY", @ran_key, 1)
            return ran.to_i == 0
          end
        end
      end
    end
  end
end
