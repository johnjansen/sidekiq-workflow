# frozen_string_literal: true

module Sidekiq
  module Workflow
    # A minimal schema/typed-data base class.
    #
    # It is designed to validate Sidekiq job arguments which must be JSON-native
    # (strings/numbers/booleans/nil/arrays/hashes with string keys).
    class Schema
      class << self
        def required(name, type, default: :__no_default__)
          define_field(name, type, required: true, default: default)
        end

        def optional(name, type, default: :__no_default__)
          define_field(name, type, required: false, default: default)
        end

        def fields
          @fields ||= {}
        end

        def from_hash(hash)
          new(hash)
        end

        private

        def define_field(name, type, required:, default:)
          key = name.to_s
          fields[key] = {
            name: name.to_sym,
            type: type,
            required: required,
            default: default
          }

          attr_reader name
        end
      end

      def initialize(attrs = {})
        raise ArgumentError, "Schema input must be a Hash" unless attrs.is_a?(Hash)

        attrs = attrs.transform_keys(&:to_s)

        unknown = attrs.keys - self.class.fields.keys
        raise ArgumentError, "Unknown keys: #{unknown.sort.join(", ")}" if unknown.any?

        self.class.fields.each do |key, spec|
          value = if attrs.key?(key)
            attrs[key]
          elsif spec.fetch(:default) != :__no_default__
            spec.fetch(:default)
          elsif spec.fetch(:required)
            raise ArgumentError, "Missing required key: #{key}"
          end

          value = coerce_value(spec.fetch(:type), value, key)

          instance_variable_set("@#{spec.fetch(:name)}", value)
        end
      end

      def to_h
        self.class.fields.each_with_object({}) do |(key, spec), hash|
          value = instance_variable_get("@#{spec.fetch(:name)}")
          hash[key] = dump_value(value)
        end
      end

      private

      def coerce_value(type, value, key)
        return nil if value.nil?

        if type.is_a?(Class) && type < Sidekiq::Workflow::Schema
          return value if value.is_a?(type)
          raise TypeError, "#{key} must be a Hash or #{type}" unless value.is_a?(Hash)

          return type.new(value)
        end

        return value if value.is_a?(type)

        raise TypeError, "#{key} must be a #{type}, got #{value.class}"
      end

      def dump_value(value)
        return value.to_h if value.is_a?(Sidekiq::Workflow::Schema)
        value
      end
    end
  end
end
