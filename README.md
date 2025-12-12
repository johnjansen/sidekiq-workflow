# sidekiq-workflow

`sidekiq-workflow` allows defining workflows (chains and groups of jobs) on top of Sidekiq.

It is intentionally modeled after the approach in `dramatiq-workflow`:

- Workflows are composed from `Chain`, `Group`, and `WithDelay` primitives.
- Each job carries a **stack of completion callbacks** in its payload.
- A server middleware processes callbacks after successful job execution.
- **Redis barriers** (atomic counters) coordinate group completion.

## Installation

Add to your Gemfile:

```ruby
gem "sidekiq-workflow"
```

## Setup

Add the server middleware:

```ruby
require "sidekiq/workflow"

Sidekiq.configure_server do |config|
  config.server_middleware do |chain|
    chain.add Sidekiq::Workflow::Middleware
  end
end
```

## Example

```ruby
require "sidekiq/workflow"

class Task1
  include Sidekiq::Job
  def perform
    puts "Task 1"
  end
end

class Task2
  include Sidekiq::Job
  def perform
    puts "Task 2"
  end
end

class Task3
  include Sidekiq::Job
  def perform
    puts "Task 3"
  end
end

class Task4
  include Sidekiq::Job
  def perform
    puts "Task 4"
  end
end

workflow = Sidekiq::Workflow::Workflow.new(
  Sidekiq::Workflow::Chain.new(
    Sidekiq::Workflow::Job.new(Task1),
    Sidekiq::Workflow::Group.new(
      Sidekiq::Workflow::Job.new(Task2),
      Sidekiq::Workflow::Job.new(Task3)
    ),
    Sidekiq::Workflow::Job.new(Task4)
  )
)

workflow.run
```

## WithDelay

`WithDelay` delays execution by a number of **milliseconds** (to mirror `dramatiq-workflow`).

```ruby
require "sidekiq/workflow"

workflow = Sidekiq::Workflow::Workflow.new(
  Sidekiq::Workflow::Chain.new(
    Sidekiq::Workflow::WithDelay.new(Sidekiq::Workflow::Job.new(Task1), delay: 1_000),
    Sidekiq::Workflow::Job.new(Task2)
  )
)

workflow.run
```

## Typed Inputs/Outputs (Schemas)

Sidekiq jobs can optionally define an `Input` and `Output` schema (validated at runtime) by including `Sidekiq::Workflow::TypedJob`.

Notes:

- Sidekiq calls `perform(*args)` and does not pass keyword arguments.
- Typed jobs therefore expect a single Hash argument which is converted to `Input`.
- The job's return value is validated against `Output` (even though Sidekiq does not use return values).

```ruby
class Task1
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

Task1.perform_async({"field_name" => "hello"})
```

## Proof / Demo

From this repository:

```sh
cd sidekiq-workflow
bundle install
bundle exec ruby examples/proof.rb
```

The proof script starts an embedded Sidekiq instance, runs a workflow, and exits non-zero if the execution order violates the workflow DAG.
