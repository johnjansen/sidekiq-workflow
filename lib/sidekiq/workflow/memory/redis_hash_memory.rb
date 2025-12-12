# frozen_string_literal: true

module Sidekiq
  module Workflow
    module Memory
      class RedisHashMemory < Base
        def initialize(ttl: 86_400, key_prefix: "swf:mem")
          @ttl = ttl
          @key_prefix = key_prefix
        end

        def write(run_id, hash, config:)
          raise ArgumentError, "run_id is required" if run_id.nil? || run_id.to_s.empty?
          raise ArgumentError, "hash must be a Hash" unless hash.is_a?(Hash)

          key = redis_key(run_id)
          fields = hash.transform_keys(&:to_s)

          config.redis do |conn|
            conn.pipelined do |pipe|
              fields.each do |field, value|
                pipe.call("HSET", key, field, Sidekiq.dump_json(value))
              end
              pipe.call("EXPIRE", key, @ttl)
            end
          end

          true
        end

        def read(run_id, keys:, config:)
          raise ArgumentError, "run_id is required" if run_id.nil? || run_id.to_s.empty?

          redis_key = redis_key(run_id)
          keys = Array(keys).map(&:to_s)

          raws = config.redis do |conn|
            conn.pipelined do |pipe|
              keys.each { |field| pipe.call("HGET", redis_key, field) }
            end
          end

          result = {}
          keys.zip(raws).each do |field, raw|
            next if raw.nil?
            result[field] = Sidekiq.load_json(raw)
          end
          result
        end

        def clear(run_id, config:)
          raise ArgumentError, "run_id is required" if run_id.nil? || run_id.to_s.empty?

          config.redis { |conn| conn.call("DEL", redis_key(run_id)) }
          true
        end

        private

        def redis_key(run_id)
          "#{@key_prefix}:#{run_id}"
        end
      end
    end
  end
end
