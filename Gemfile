source "https://rubygems.org"

gemspec

# Use the local Sidekiq checkout in this monorepo.
gem "sidekiq", path: "../sidekiq"

gem "rake"

group :test do
  gem "minitest"
end

group :development, :test do
  gem "standard", require: false
end
