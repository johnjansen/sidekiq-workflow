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

## Memory (for DAG-style data passing)

Sidekiq does not use a job's return value, so output schemas are only useful if you persist the output somewhere.

`sidekiq-workflow` supports an optional, pluggable per-workflow **memory** backend: a per-run key/value store.

### How it works

- `Workflow#run` generates a `workflow_run_id` (UUID) and attaches it to every enqueued job payload under `workflow_run_id`.
- `Sidekiq::Workflow::Middleware` wraps job execution in a runtime context (run_id + Sidekiq config), then:
  - persists the job's return value into memory (when it is a `Hash` or a `Sidekiq::Workflow::Schema`)
  - advances completion callbacks

### Input hydration (TypedJob)

When a job includes `Sidekiq::Workflow::TypedJob` and defines `Input`, the input hash is built like:

1. Start with memory values for the keys defined in `Input`
2. Merge in the job's provided argument hash (provided keys win)
3. Validate/construct an `Input` instance

Typed jobs can therefore be enqueued with **no args** if their `Input` can be fully hydrated from memory.

### Output persistence

On successful job completion, the middleware writes the returned hash/schema to memory for the current `workflow_run_id`.

If you "mutate the input", you must return the mutated value if you want it persisted for downstream steps.

### Backends

A memory backend must implement:

- `write(run_id, hash, config:)`
- `read(run_id, keys:, config:)`
- `clear(run_id, config:)`

Included backend:

- `Sidekiq::Workflow::Memory::RedisHashMemory` – stores values as JSON in a Redis hash keyed by `key_prefix:run_id` with TTL.

### Configuration

```ruby
Sidekiq::Workflow.configure do |cfg|
  cfg.memory = Sidekiq::Workflow::Memory::RedisHashMemory.new(ttl: 300, key_prefix: "swf:mem")
end
```

### Concurrency / key collisions

Memory is a flat hash per run. If multiple parallel tasks write the same key, last write wins.

For group-heavy DAGs, prefer namespacing keys (e.g. `"task1.something"`) or implement a custom backend/merging strategy.

### Example

A runnable example exists at `examples/memory.rb`.

## Templates (named, parameterized workflows)

For larger workflows (e.g. "enrich and index"), you often want to define a DAG shape once and run it many times with different configs.

`sidekiq-workflow` provides a small in-process template registry:

- `Sidekiq::Workflow::Templates.register("name", input: SomeSchema) { |input| ... }`
- `Sidekiq::Workflow::Templates.run("name", params_hash)`

### Ergonomic config passing via memory + TypedJob

If workflow memory is configured, `Templates.run` will pre-write the template params into memory for the new `workflow_run_id`.

Jobs which include `Sidekiq::Workflow::TypedJob` can then be enqueued with **no args**; their `Input` schema is hydrated from memory.

Job argument hashes still override memory values for a given key.

### Baking template config (e.g. from YAML)

A common pattern is:

- Load a template config once (e.g. from YAML at boot)
- Treat those values as defaults in the template `Input` schema
- Require only the truly run-specific input at runtime (e.g. `doc_id`)

Because `Templates.run` seeds the constructed `Input` into memory, the defaults are applied and persisted for the run.

See `examples/templates_yaml.rb` (loads `examples/config/enrich_and_index.yml`).

```ruby
require "yaml"

Sidekiq::Workflow.configure do |cfg|
  cfg.memory = Sidekiq::Workflow::Memory::RedisHashMemory.new(ttl: 300, key_prefix: "swf:mem")
end

template_config = YAML.load_file("./examples/config/enrich_and_index.yml").transform_keys(&:to_s)

class EnrichAndIndexInput < Sidekiq::Workflow::Schema
  required :doc_id, String
  required :llm_model, String, default: template_config.fetch("llm_model")
  required :index_name, String, default: template_config.fetch("index_name")
end

Sidekiq::Workflow::Templates.register("enrich_and_index", input: EnrichAndIndexInput) do |_input|
  Sidekiq::Workflow::Chain.new(
    Sidekiq::Workflow::Job.new(FetchDoc),
    Sidekiq::Workflow::Job.new(EnrichDoc),
    Sidekiq::Workflow::Job.new(IndexDoc)
  )
end

# Per-run, only pass the truly run-specific input.
run_id = Sidekiq::Workflow::Templates.run("enrich_and_index", {"doc_id" => "123"})
```

Runnable examples exist at `examples/templates.rb` and `examples/templates_yaml.rb`.

## Barriers (group completion) and TTL

Groups use Redis barrier keys (atomic counters) to coordinate completion.

The default barrier implementation is `Sidekiq::Workflow::Barrier::AtMostOnceBarrier`:

- It is **at-most-once** for the continuation: it tries to ensure only one worker releases a given barrier.
- Continuation enqueueing is **active** (it happens immediately when the barrier is released), but it is **not atomic** with the barrier release.

This means there is a rare crash window where a worker can release the barrier but die before it enqueues the continuation, leaving the workflow "stuck" until manual intervention.

Barrier keys are created with a TTL (`cfg.barrier_ttl`) primarily as a garbage-collection mechanism. For long-running jobs/workflows, you may want to refresh barrier TTL.

### Refreshing barrier TTL from inside `perform`

From inside a running job, you can refresh the TTL on any barrier keys referenced by that job's workflow callbacks:

```ruby
Sidekiq::Workflow.extend_ttl!(ttl: 300)
```

## Proof / Demo

From this repository:

```sh
cd sidekiq-workflow
bundle install
bundle exec ruby examples/proof.rb
```

The proof script starts an embedded Sidekiq instance, runs a workflow, and exits non-zero if the execution order violates the workflow DAG.
