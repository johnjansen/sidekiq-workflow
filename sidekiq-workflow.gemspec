# frozen_string_literal: true

require_relative "lib/sidekiq/workflow/version"

Gem::Specification.new do |gem|
  gem.name = "sidekiq-workflow"
  gem.version = Sidekiq::Workflow::VERSION

  gem.summary = "Workflow orchestration for Sidekiq (chains and groups)"
  gem.description = "sidekiq-workflow allows defining workflows of Sidekiq jobs using Chains and Groups, similar to Celery canvas or dramatiq-workflow."

  gem.authors = ["johnjansen"]
  gem.email = ["johnjansen@users.noreply.github.com"]

  gem.homepage = "https://github.com/johnjansen/sidekiq-workflow"
  gem.license = "MIT"

  gem.required_ruby_version = ">= 3.2.0"

  gem.files = (Dir["lib/**/*", "README.md", "LICENSE.txt", "examples/**/*"])

  gem.add_dependency "sidekiq", ">= 7.0.0"
end
