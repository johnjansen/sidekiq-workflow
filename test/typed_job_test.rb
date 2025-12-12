# frozen_string_literal: true

require_relative "helper"

class TypedJobTest < Minitest::Test
  class TaskWithSchema
    include Sidekiq::Job
    include Sidekiq::Workflow::TypedJob

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

  class TaskWithBadOutput
    include Sidekiq::Job
    include Sidekiq::Workflow::TypedJob

    class Input < Sidekiq::Workflow::Schema
      required :field_name, String
    end

    class Output < Sidekiq::Workflow::Schema
      required :something, String
    end

    def perform(_input)
      {"something" => 123}
    end
  end

  def test_converts_input_hash_to_schema_instance_and_validates_output
    output = TaskWithSchema.new.perform({"field_name" => "hello"})

    assert_instance_of TaskWithSchema::Output, output
    assert_equal({"something" => "hello"}, output.to_h)
  end

  def test_rejects_missing_required_input
    assert_raises(ArgumentError) do
      TaskWithSchema.new.perform({})
    end
  end

  def test_rejects_unknown_input_keys
    assert_raises(ArgumentError) do
      TaskWithSchema.new.perform({"field_name" => "ok", "extra" => 1})
    end
  end

  def test_rejects_wrong_input_type
    assert_raises(TypeError) do
      TaskWithSchema.new.perform({"field_name" => 123})
    end
  end

  def test_rejects_wrong_output_type
    assert_raises(TypeError) do
      TaskWithBadOutput.new.perform({"field_name" => "hello"})
    end
  end

  def test_schema_allows_typed_assignment_with_validation
    input = TaskWithSchema::Input.new({"field_name" => "hello"})
    input.field_name = "world"
    assert_equal "world", input.field_name

    assert_raises(TypeError) do
      input.field_name = 123
    end
  end
end
