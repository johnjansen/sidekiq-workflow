# Named / templated DAGs (notes)

This is a scratchpad for an eventual "named templated DAG" feature.

## Goal

Make it easy to:

- Define a workflow DAG once (a "template")
- Instantiate it with run-specific inputs
- Optionally attach the template name/version to runs for introspection

## Baseline approach (Ruby registry)

Add a small in-process registry of templates.

- Templates are registered by a string name
- Template builder receives a params object (ideally a `Sidekiq::Workflow::Schema`)
- Builder returns a workflow node (`Job`, `Chain`, `Group`, `WithDelay`)

Example:

```ruby
class CheckoutInput < Sidekiq::Workflow::Schema
  required :events_key, String
end

Sidekiq::Workflow::Templates.register("checkout", input: CheckoutInput) do |input|
  Sidekiq::Workflow::Chain.new(
    Sidekiq::Workflow::Job.new(Task1, input.events_key),
    Sidekiq::Workflow::Job.new(Task2, input.events_key)
  )
end

Sidekiq::Workflow::Templates.run("checkout", {"events_key" => "events"})
```

Pros:

- Very small surface area
- No changes required to the workflow engine
- Plays well with existing `Schema` types

Cons:

- Template is only available in-process (must be registered on boot)
- No built-in versioning/immutability story

## Attaching template metadata to a run

If we want to query "which template is this run using?", we can:

- Option A: Write metadata into memory at the start (e.g. reserved keys)
- Option B: Attach `workflow_template_name` (and optionally `workflow_template_version`) into every enqueued job payload

Option A is easiest if memory is configured.

Option B works even without memory, but requires changes to `Workflow#enqueue_job` (or wrapping `Job#sidekiq_item`).

## Reducing callback payload size

Right now the callback stack stores `remaining_workflow` as a full serialized structure.

If this becomes large, we can add a "template reference" callback payload:

- `remaining_workflow` becomes either:
  - `{ "__type__": "workflow", ... }` (current)
  - or `{ "__type__": "template_ref", "name": "checkout", "cursor": {...}, "params": {...} }`

The hard part is defining the cursor:

- For `Chain`, cursor can be an index into a known task list
- For `Group`, cursor is mostly the barrier id + remaining stack
- For nested graphs, we likely need a structured path into the template

A practical constraint: in-flight runs should be reproducible. That implies template refs should be versioned/immutable.

## Versioning / immutability

If template refs are persisted anywhere (callbacks, memory), template changes must not change the meaning of already-enqueued work.

Options:

- Require explicit version strings and treat `name@version` as immutable
- Store a hash of the serialized template definition (`sha256`) and treat that as identity
- Persist a full serialized copy in callback storage and only use the name for human labeling

## Next questions

- Should templates be a purely-local Ruby API, or stored/published in Redis?
- Do we want template refs primarily for human introspection, or for payload-size reductions?
- Do we need a stable template identity (version/hash) from day one?
