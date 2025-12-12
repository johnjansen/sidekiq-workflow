# frozen_string_literal: true

module Sidekiq
  module Workflow
    module Memory
      class Base
        def write(_run_id, _hash, config:)
          raise NotImplementedError
        end

        def read(_run_id, keys:, config:)
          raise NotImplementedError
        end

        def clear(_run_id, config:)
          raise NotImplementedError
        end
      end
    end
  end
end
