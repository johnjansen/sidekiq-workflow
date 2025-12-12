# frozen_string_literal: true

ENV["REDIS_URL"] ||= "redis://localhost:6379/15"

require "bundler/setup"

require "sidekiq"
require "sidekiq/testing"
require "sidekiq/workflow"

Sidekiq::Testing.inline!

class TypedExampleTask
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
    {"something" => input.field_name.upcase}
  end
end

puts "Direct call (returns typed Output):"
output = TypedExampleTask.new.perform({"field_name" => "hello"})
puts output.class.name
puts output.to_h.inspect

puts "\nSidekiq inline run (TypedJob validates but return value is not used by Sidekiq):"
jid = TypedExampleTask.perform_async({"field_name" => "world"})
puts "jid=#{jid}"

puts "\nBad input (expected error):"
begin
  TypedExampleTask.perform_async({"field_name" => 123})
rescue => e
  puts "#{e.class}: #{e.message}"
end
