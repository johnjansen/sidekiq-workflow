# frozen_string_literal: true

module Sidekiq
  module Sideline
    class Job
      attr_reader :klass_name
      attr_reader :args
      attr_reader :options

      def initialize(klass, *args, **options)
        @klass_name = klass.is_a?(Class) ? klass.name : klass.to_s
        raise ArgumentError, "Job class must be a Class or String" if @klass_name.nil? || @klass_name.empty?

        @args = args
        @options = options.transform_keys(&:to_s)
      end

      def self.from_h(hash)
        data = hash.dup
        data.delete("__type__")

        klass_name = data.delete("class")
        args = data.delete("args") || []
        options = data.transform_keys(&:to_sym)

        new(klass_name, *args, **options)
      end

      def to_h
        {"class" => klass_name, "args" => args}.merge(options)
      end

      def sidekiq_item
        klass = Object.const_get(klass_name)
        {"class" => klass, "args" => args}.merge(options)
      end

      def ==(other)
        other.is_a?(Job) && klass_name == other.klass_name && args == other.args && options == other.options
      end

      def to_s
        "Job(#{to_h})"
      end
    end
  end
end
