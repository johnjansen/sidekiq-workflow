# frozen_string_literal: true

require_relative "lib/sidekiq/sideline/version"

Gem::Specification.new do |gem|
  gem.name = "sidekiq-sideline"
  gem.version = Sidekiq::Sideline::VERSION

  gem.summary = "Workflow orchestration for Sidekiq (chains and groups)"
  gem.description = "sidekiq-sideline allows defining workflows of Sidekiq jobs using Chains and Groups, similar to Celery canvas or dramatiq-workflow."

  gem.authors = ["johnjansen"]
  gem.email = ["johnjansen@users.noreply.github.com"]

  gem.homepage = "https://github.com/johnjansen/sidekiq-sideline"
  gem.license = "MIT"

  gem.required_ruby_version = ">= 3.2.0"

  gem.files = (Dir["lib/**/*", "README.md", "LICENSE.txt", "examples/**/*"])

  # We only target recent Sidekiq versions.
  gem.add_dependency "sidekiq", "~> 8.0"
end
